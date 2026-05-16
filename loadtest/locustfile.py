from locust import HttpUser, between, task


class EcommerceUser(HttpUser):
    wait_time = between(0.05, 0.2)

    @task(4)
    def list_products(self):
        self.client.get("/products", name="/products")

    @task(2)
    def checkout(self):
        self.client.post(
            "/checkout",
            json={"product_id": "sku-001", "quantity": 1},
            name="/checkout",
        )

    @task(1)
    def health(self):
        self.client.get("/healthz", name="/healthz")

