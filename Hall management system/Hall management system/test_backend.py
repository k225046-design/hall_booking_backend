import unittest
from datetime import date, timedelta

from backendcode import Booking, BookingMessage, Customer, HallFeedback, app, db


class BackendSmokeTests(unittest.TestCase):
    test_email = "smoke_test_user@example.com"

    def setUp(self) -> None:
        self.client = app.test_client()
        with app.app_context():
            self._cleanup_test_user()

    def tearDown(self) -> None:
        with app.app_context():
            self._cleanup_test_user()

    def _cleanup_test_user(self) -> None:
        customer = Customer.query.filter_by(email=self.test_email).first()
        if not customer:
            return
        booking_ids = [
            booking_id
            for (booking_id,) in db.session.query(Booking.hall_booking_id)
            .filter_by(customer_id=customer.id)
            .all()
        ]
        if booking_ids:
            BookingMessage.query.filter(
                BookingMessage.booking_id.in_(booking_ids)
            ).delete(synchronize_session=False)
        HallFeedback.query.filter_by(customer_id=customer.id).delete()
        Booking.query.filter_by(customer_id=customer.id).delete()
        db.session.delete(customer)
        db.session.commit()

    def test_health_endpoint(self) -> None:
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertEqual(payload["status"], "ok")
        self.assertIn("date", payload)

    def test_register_requires_required_fields(self) -> None:
        response = self.client.post("/register", json={})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json(), {"error": "Name is required."})

    def test_customer_can_register_login_and_book(self) -> None:
        register_response = self.client.post(
            "/register",
            json={
                "name": "Smoke Test User",
                "email": self.test_email,
                "phone": "03001234567",
                "password": "secret123",
                "favorite_category": "Luxury",
            },
        )
        self.assertEqual(register_response.status_code, 201)

        login_response = self.client.post(
            "/login",
            json={"email": self.test_email, "password": "secret123"},
        )
        self.assertEqual(login_response.status_code, 200)
        login_payload = login_response.get_json()
        self.assertEqual(login_payload["role"], "customer")

        booking_response = self.client.post(
            "/book",
            json={
                "hall_id": 1,
                "customer_id": login_payload["user"]["id"],
                "booking_date": (date.today() + timedelta(days=10)).isoformat(),
                "guest_count": 150,
                "event_type": "Wedding",
            },
        )

        self.assertEqual(booking_response.status_code, 201)
        booking_payload = booking_response.get_json()
        self.assertEqual(booking_payload["booking"]["status"], "pending")
        self.assertEqual(booking_payload["booking"]["guest_count"], 150)
        self.assertEqual(booking_payload["booking"]["messages"], [])

    def test_booking_messages_flow_between_admin_and_customer(self) -> None:
        register_response = self.client.post(
            "/register",
            json={
                "name": "Smoke Test User",
                "email": self.test_email,
                "phone": "03001234567",
                "password": "secret123",
                "favorite_category": "Luxury",
            },
        )
        self.assertEqual(register_response.status_code, 201)

        login_response = self.client.post(
            "/login",
            json={"email": self.test_email, "password": "secret123"},
        )
        self.assertEqual(login_response.status_code, 200)
        customer_id = login_response.get_json()["user"]["id"]

        booking_response = self.client.post(
            "/book",
            json={
                "hall_id": 1,
                "customer_id": customer_id,
                "booking_date": (date.today() + timedelta(days=15)).isoformat(),
                "guest_count": 120,
                "event_type": "Wedding",
            },
        )
        self.assertEqual(booking_response.status_code, 201)
        booking_id = booking_response.get_json()["booking"]["hall_booking_id"]

        admin_message_response = self.client.post(
            f"/admin/send_booking_message/{booking_id}",
            json={"message": "Please confirm your decor preferences."},
        )
        self.assertEqual(admin_message_response.status_code, 200)

        customer_message_response = self.client.post(
            f"/customer/send_booking_message/{booking_id}",
            json={
                "customer_id": customer_id,
                "message": "We prefer a white floral theme.",
            },
        )
        self.assertEqual(customer_message_response.status_code, 200)

        bookings_response = self.client.get(f"/customer/bookings/{customer_id}")
        self.assertEqual(bookings_response.status_code, 200)
        bookings = bookings_response.get_json()
        self.assertEqual(len(bookings), 1)
        messages = bookings[0]["messages"]
        self.assertEqual(len(messages), 2)
        self.assertEqual(messages[0]["sender_role"], "admin")
        self.assertEqual(messages[1]["sender_role"], "customer")

    def test_invalid_guest_count_returns_400(self) -> None:
        with app.app_context():
            customer = Customer(
                name="Booking Validation User",
                email=self.test_email,
                phone="03001234567",
                password_hash="hashed",
            )
            db.session.add(customer)
            db.session.commit()
            customer_id = customer.id

        response = self.client.post(
            "/book",
            json={
                "hall_id": 1,
                "customer_id": customer_id,
                "booking_date": (date.today() + timedelta(days=3)).isoformat(),
                "guest_count": "abc",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.get_json(),
            {"error": "Guest count must be a valid number."},
        )

    def test_invalid_hall_payload_returns_400(self) -> None:
        response = self.client.post(
            "/admin/halls",
            json={
                "name": "Bad Hall",
                "location": "Karachi",
                "capacity": "abc",
                "rent": "-10",
                "contact_person": "Admin",
                "phone_number": "123",
                "email": "bad@example.com",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.get_json(),
            {"error": "Capacity must be a valid number."},
        )

    def test_customer_can_submit_feedback(self) -> None:
        register_response = self.client.post(
            "/register",
            json={
                "name": "Smoke Test User",
                "email": self.test_email,
                "phone": "03001234567",
                "password": "secret123",
            },
        )
        self.assertEqual(register_response.status_code, 201)

        login_response = self.client.post(
            "/login",
            json={"email": self.test_email, "password": "secret123"},
        )
        customer_id = login_response.get_json()["user"]["id"]

        booking_response = self.client.post(
            "/book",
            json={
                "hall_id": 1,
                "customer_id": customer_id,
                "booking_date": (date.today() + timedelta(days=20)).isoformat(),
                "guest_count": 180,
                "event_type": "Wedding",
            },
        )
        self.assertEqual(booking_response.status_code, 201)

        feedback_response = self.client.post(
            "/hall/1/feedback",
            json={
                "customer_id": customer_id,
                "rating": 5,
                "comment": "Beautiful decor and very cooperative staff.",
            },
        )
        self.assertEqual(feedback_response.status_code, 201)
        payload = feedback_response.get_json()
        self.assertEqual(payload["feedback"]["rating"], 5)
        self.assertGreaterEqual(payload["summary"]["feedback_count"], 1)

    def test_nearest_hall_search_returns_distance(self) -> None:
        response = self.client.get("/halls?nearest_to=Karachi")

        self.assertEqual(response.status_code, 200)
        halls = response.get_json()
        self.assertGreater(len(halls), 0)
        self.assertIn("distance_km", halls[0])
        self.assertIn("average_rating", halls[0])
        self.assertIn("feedback_count", halls[0])
        self.assertEqual(halls[0]["location"], "Karachi")


if __name__ == "__main__":
    unittest.main()
