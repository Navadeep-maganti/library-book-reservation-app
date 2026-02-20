from django.contrib.auth import authenticate, get_user_model
from rest_framework import serializers
from rest_framework.authtoken.models import Token

User = get_user_model()


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        identifier = data["username"].strip()
        password = data["password"]

        user = authenticate(username=identifier, password=password)

        if not user:
            fallback_user = User.objects.filter(student_id=identifier).first()
            if fallback_user:
                user = authenticate(username=fallback_user.username, password=password)

        if not user:
            raise serializers.ValidationError("Invalid credentials")

        token, _ = Token.objects.get_or_create(user=user)

        return {
            "token": token.key,
            "username": user.username,
            "user_id": user.id,
            "role": user.role,
            "student_id": user.student_id,
        }
