from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase

from .models import User


@override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"])
class RegisterViewTests(APITestCase):
    def test_register_creates_student_account_and_returns_auth_payload(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "username": "newstudent",
                "student_id": "STU-1001",
                "password": "StrongPass123",
                "confirm_password": "StrongPass123",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["username"], "newstudent")
        self.assertEqual(response.data["role"], User.Roles.STUDENT)
        self.assertTrue(response.data["token"])
        self.assertTrue(
            User.objects.filter(
                username="newstudent",
                student_id="STU-1001",
                role=User.Roles.STUDENT,
            ).exists()
        )

    def test_register_rejects_duplicate_student_id(self):
        User.objects.create_user(
            username="existing",
            password="StrongPass123",
            student_id="STU-2002",
        )

        response = self.client.post(
            "/api/auth/register/",
            {
                "username": "another",
                "student_id": "STU-2002",
                "password": "StrongPass123",
                "confirm_password": "StrongPass123",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("student_id", response.data)
