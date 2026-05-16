package app

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Config struct {
	ServiceName string
	Version     string
}

type Server struct {
	config          Config
	startedAt       time.Time
	registry        *prometheus.Registry
	requestsTotal   *prometheus.CounterVec
	requestDuration *prometheus.HistogramVec
	inFlight        prometheus.Gauge
}

type Product struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	PriceCents int    `json:"price_cents"`
	InStock    int    `json:"in_stock"`
}

type checkoutRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
}

type checkoutResponse struct {
	OrderID    string `json:"order_id"`
	ProductID  string `json:"product_id"`
	Quantity   int    `json:"quantity"`
	TotalCents int    `json:"total_cents"`
	Status     string `json:"status"`
}

var products = []Product{
	{ID: "sku-001", Name: "Production Readiness Hoodie", PriceCents: 12900, InStock: 128},
	{ID: "sku-002", Name: "SLO Coffee Mug", PriceCents: 5900, InStock: 256},
	{ID: "sku-003", Name: "Incident Commander Notebook", PriceCents: 7900, InStock: 96},
}

func New(config Config) *Server {
	if config.ServiceName == "" {
		config.ServiceName = "ecommerce-api"
	}
	if config.Version == "" {
		config.Version = "dev"
	}

	registry := prometheus.NewRegistry()
	requestsTotal := prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Namespace: "ecommerce",
			Subsystem: "api",
			Name:      "http_requests_total",
			Help:      "Total HTTP requests handled by the API.",
		},
		[]string{"method", "route", "status"},
	)

	requestDuration := prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Namespace: "ecommerce",
			Subsystem: "api",
			Name:      "http_request_duration_seconds",
			Help:      "HTTP request latency in seconds.",
			Buckets:   []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5},
		},
		[]string{"method", "route"},
	)

	inFlight := prometheus.NewGauge(prometheus.GaugeOpts{
		Namespace: "ecommerce",
		Subsystem: "api",
		Name:      "http_in_flight_requests",
		Help:      "Current in-flight HTTP requests.",
	})

	buildInfo := prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Namespace: "ecommerce",
			Subsystem: "api",
			Name:      "build_info",
			Help:      "Build metadata for the running API.",
		},
		[]string{"service", "version"},
	)

	registry.MustRegister(requestsTotal, requestDuration, inFlight, buildInfo)
	buildInfo.WithLabelValues(config.ServiceName, config.Version).Set(1)

	return &Server{
		config:          config,
		startedAt:       time.Now().UTC(),
		registry:        registry,
		requestsTotal:   requestsTotal,
		requestDuration: requestDuration,
		inFlight:        inFlight,
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("GET /{$}", s.withMetrics("/", http.HandlerFunc(s.handleRoot)))
	mux.Handle("GET /healthz", s.withMetrics("/healthz", http.HandlerFunc(s.handleHealth)))
	mux.Handle("GET /readyz", s.withMetrics("/readyz", http.HandlerFunc(s.handleReady)))
	mux.Handle("GET /products", s.withMetrics("/products", http.HandlerFunc(s.handleProducts)))
	mux.Handle("POST /checkout", s.withMetrics("/checkout", http.HandlerFunc(s.handleCheckout)))
	mux.Handle("/metrics", promhttp.HandlerFor(s.registry, promhttp.HandlerOpts{}))
	return mux
}

func (s *Server) handleRoot(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service":    s.config.ServiceName,
		"version":    s.config.Version,
		"started_at": s.startedAt.Format(time.RFC3339),
		"status":     "ok",
	})
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleReady(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *Server) handleProducts(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"products": products})
}

func (s *Server) handleCheckout(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var request checkoutRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json body"})
		return
	}
	request.ProductID = strings.TrimSpace(request.ProductID)
	if request.ProductID == "" || request.Quantity <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "product_id and positive quantity are required"})
		return
	}

	product, ok := findProduct(request.ProductID)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "product not found"})
		return
	}
	if request.Quantity > product.InStock {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "not enough stock"})
		return
	}

	writeJSON(w, http.StatusCreated, checkoutResponse{
		OrderID:    fmt.Sprintf("ord_%d", time.Now().UnixNano()),
		ProductID:  product.ID,
		Quantity:   request.Quantity,
		TotalCents: product.PriceCents * request.Quantity,
		Status:     "accepted",
	})
}

func (s *Server) withMetrics(route string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		recorder := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		startedAt := time.Now()

		s.inFlight.Inc()
		defer func() {
			s.inFlight.Dec()
			status := strconv.Itoa(recorder.statusCode)
			s.requestsTotal.WithLabelValues(r.Method, route, status).Inc()
			s.requestDuration.WithLabelValues(r.Method, route).Observe(time.Since(startedAt).Seconds())
		}()

		next.ServeHTTP(recorder, r)
	})
}

func findProduct(id string) (Product, bool) {
	for _, product := range products {
		if product.ID == id {
			return product, true
		}
	}
	return Product{}, false
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}
