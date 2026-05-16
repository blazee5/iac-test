package app

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	server := New(Config{ServiceName: "test-api", Version: "test"}).Handler()
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	server.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", response.Code)
	}
	if !strings.Contains(response.Body.String(), `"status":"ok"`) {
		t.Fatalf("unexpected response body: %s", response.Body.String())
	}
}

func TestCheckoutEndpoint(t *testing.T) {
	server := New(Config{ServiceName: "test-api", Version: "test"}).Handler()
	body := bytes.NewBufferString(`{"product_id":"sku-001","quantity":2}`)
	request := httptest.NewRequest(http.MethodPost, "/checkout", body)
	response := httptest.NewRecorder()

	server.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", response.Code, response.Body.String())
	}

	var payload checkoutResponse
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.ProductID != "sku-001" || payload.Quantity != 2 || payload.Status != "accepted" {
		t.Fatalf("unexpected checkout response: %+v", payload)
	}
}

func TestMetricsEndpoint(t *testing.T) {
	server := New(Config{ServiceName: "test-api", Version: "test"}).Handler()

	server.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/products", nil))
	response := httptest.NewRecorder()
	server.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/metrics", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", response.Code)
	}
	body := response.Body.String()
	if !strings.Contains(body, "ecommerce_api_http_requests_total") {
		t.Fatalf("metrics output does not include request counter: %s", body)
	}
	if !strings.Contains(body, "ecommerce_api_http_request_duration_seconds_bucket") {
		t.Fatalf("metrics output does not include latency histogram: %s", body)
	}
}
