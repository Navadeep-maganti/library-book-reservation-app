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


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["username", "student_id", "password", "confirm_password"]

    def validate_username(self, value):
        username = value.strip()
        if User.objects.filter(username__iexact=username).exists():
            raise serializers.ValidationError("Username is already taken.")
        return username

    def validate_student_id(self, value):
        student_id = value.strip()
        if not student_id:
            raise serializers.ValidationError("Student ID is required.")
        if User.objects.filter(student_id__iexact=student_id).exists():
            raise serializers.ValidationError("Student ID is already registered.")
        return student_id

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {"confirm_password": "Passwords do not match."}
            )
        return attrs

    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        user = User(**validated_data, role=User.Roles.STUDENT)
        user.set_password(password)
        user.save()
        Token.objects.get_or_create(user=user)
        return user
