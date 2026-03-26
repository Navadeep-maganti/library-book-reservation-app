from datetime import timedelta
from uuid import uuid4

from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from accounts.models import User

from .models import (
    Announcement,
    Book,
    BookReservation,
    BorrowHistory,
    Fine,
    IssuedBook,
    Notification,
    PushDevice,
)


class NotificationSyncTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.student = User.objects.create_user(
            username=f"student-{uuid4().hex[:8]}",
            password="secret123",
            role=User.Roles.STUDENT,
        )
        token = Token.objects.create(user=self.student)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        self.book = Book.objects.create(
            title="Clean Code",
            author="Robert C. Martin",
            isbn=f"test-isbn-{uuid4().hex[:10]}",
            total_copies=3,
            available_copies=2,
        )

    def test_notifications_endpoint_creates_due_reminder_once(self):
        IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() + timedelta(days=1),
        )

        first_response = self.client.get("/api/notifications/")
        second_response = self.client.get("/api/notifications/")

        self.assertEqual(first_response.status_code, 200)
        self.assertEqual(second_response.status_code, 200)
        self.assertEqual(Notification.objects.filter(student=self.student).count(), 1)
        self.assertEqual(Notification.objects.get(student=self.student).notification_type, "due_reminder")

    def test_unread_count_syncs_announcements(self):
        Announcement.objects.create(
            title="Library Closed Early",
            content="The library will close at 4 PM today.",
            is_active=True,
        )

        response = self.client.get("/api/notifications/unread_count/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["unread_count"], 1)
        self.assertTrue(
            Notification.objects.filter(
                student=self.student,
                notification_type="announcement",
            ).exists()
        )

    def test_mark_all_read_marks_existing_notifications(self):
        Notification.objects.create(
            student=self.student,
            notification_type="system",
            title="Welcome",
            message="Hello there",
        )

        response = self.client.post("/api/notifications/mark_all_read/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["marked_count"], 1)
        self.assertFalse(Notification.objects.filter(student=self.student, is_read=False).exists())

    def test_reservation_creates_waiting_list_notification(self):
        self.book.available_copies = 0
        self.book.save(update_fields=["available_copies"])

        response = self.client.post(
            "/api/reservations/reserve/",
            {"book_id": self.book.id},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(
            Notification.objects.filter(
                student=self.student,
                notification_type="waiting_list",
                related_book=self.book,
            ).exists()
        )

    def test_push_device_can_be_registered(self):
        response = self.client.post(
            "/api/push-devices/",
            {
                "token": "fcm-test-token",
                "platform": "android",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            PushDevice.objects.filter(
                student=self.student,
                token="fcm-test-token",
                platform="android",
                is_active=True,
            ).exists()
        )

    def test_push_device_can_be_registered_without_trailing_slash(self):
        response = self.client.post(
            "/api/push-devices",
            {
                "token": "fcm-test-token-no-slash",
                "platform": "android",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            PushDevice.objects.filter(
                student=self.student,
                token="fcm-test-token-no-slash",
                platform="android",
                is_active=True,
            ).exists()
        )

    def test_expired_hold_creates_notification_and_restores_book_copy(self):
        self.book.available_copies = 0
        self.book.save(update_fields=["available_copies"])
        reservation = BookReservation.objects.create(
            student=self.student,
            book=self.book,
            queue_position=1,
            status="notified",
            expected_available_date=timezone.now() - timedelta(minutes=1),
        )

        response = self.client.get("/api/reservations/")

        self.assertEqual(response.status_code, 200)
        reservation.refresh_from_db()
        self.book.refresh_from_db()
        self.assertEqual(reservation.status, "expired")
        self.assertEqual(self.book.available_copies, 1)
        self.assertTrue(
            Notification.objects.filter(
                student=self.student,
                title=f"Reservation Expired: {self.book.title}",
                dedupe_key=f"reservation:{reservation.id}:expired",
            ).exists()
        )

    def test_third_reservation_attempt_for_same_book_is_blocked_for_day(self):
        BookReservation.objects.create(
            student=self.student,
            book=self.book,
            queue_position=1,
            status="expired",
            expected_available_date=timezone.now() - timedelta(hours=3),
        )
        BookReservation.objects.create(
            student=self.student,
            book=self.book,
            queue_position=1,
            status="cancelled",
        )

        response = self.client.post(
            "/api/reservations/reserve/",
            {"book_id": self.book.id},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("both reservation attempts", response.data["error"])
        self.assertTrue(
            Notification.objects.filter(
                student=self.student,
                title=f"Reservation Limit Reached: {self.book.title}",
            ).exists()
        )

    def test_manual_reservation_issue_status_creates_issued_book(self):
        reservation = BookReservation.objects.create(
            student=self.student,
            book=self.book,
            queue_position=1,
            status="notified",
            expected_available_date=timezone.now() + timedelta(minutes=30),
        )

        reservation.status = "issued"
        reservation.save(update_fields=["status"])

        self.assertTrue(
            IssuedBook.objects.filter(
                student=self.student,
                book=self.book,
                is_returned=False,
            ).exists()
        )


class DynamicFineTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.student = User.objects.create_user(
            username=f"fine-student-{uuid4().hex[:8]}",
            password="secret123",
            role=User.Roles.STUDENT,
        )
        token = Token.objects.create(user=self.student)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        self.book = Book.objects.create(
            title="Domain-Driven Design",
            author="Eric Evans",
            isbn=f"fine-isbn-{uuid4().hex[:10]}",
            total_copies=2,
            available_copies=1,
        )

    def test_overdue_book_creates_dynamic_fine_before_return(self):
        IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() - timedelta(days=3, minutes=5),
        )

        response = self.client.get("/api/fines/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["fine_type"], "overdue")
        self.assertEqual(float(response.data[0]["amount"]), 30.0)

    def test_dashboard_summary_includes_dynamic_overdue_fine(self):
        IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() - timedelta(days=2, minutes=5),
        )

        response = self.client.get("/api/dashboard/summary/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["outstanding_fines"]["count"], 1)
        self.assertEqual(response.data["outstanding_fines"]["total_amount"], 20.0)

    def test_return_book_reuses_existing_overdue_fine_record(self):
        issued = IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() - timedelta(days=4, minutes=5),
        )

        self.client.get("/api/fines/")
        response = self.client.post(f"/api/borrowing/{issued.id}/return_book/", {}, format="json")

        self.assertEqual(response.status_code, 200)
        overdue_fines = Fine.objects.filter(
            student=self.student,
            issued_book=issued,
            fine_type="overdue",
        )
        self.assertEqual(overdue_fines.count(), 1)
        self.assertEqual(float(overdue_fines.first().amount), 40.0)

    def test_my_history_uses_borrow_history_for_returned_books(self):
        active_issue = IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() + timedelta(days=5),
        )
        returned_issue = IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() - timedelta(days=10),
            is_returned=True,
        )

        response = self.client.get("/api/history/my_history/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 2)
        statuses = {item["status"] for item in response.data}
        self.assertEqual(statuses, {"Active", "Returned"})
        returned_items = [item for item in response.data if item["status"] == "Returned"]
        self.assertEqual(len(returned_items), 1)
        self.assertIsNotNone(returned_items[0]["return_date"])
        active_items = [item for item in response.data if item["status"] == "Active"]
        self.assertEqual(len(active_items), 1)
        self.assertEqual(active_items[0]["book"], active_issue.book.id)
        self.assertIsNone(active_items[0]["return_date"])

    def test_manual_returned_issue_sets_return_date_and_history(self):
        issued = IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() + timedelta(days=7),
        )

        issued.is_returned = True
        issued.return_date = None
        issued.save(update_fields=["is_returned"])
        issued.refresh_from_db()

        self.assertIsNotNone(issued.return_date)
        self.assertTrue(
            BorrowHistory.objects.filter(
                student=self.student,
                book=self.book,
                issue_date=issued.issue_date,
            ).exists()
        )
