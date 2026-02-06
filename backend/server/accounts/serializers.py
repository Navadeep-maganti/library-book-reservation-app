from django.contrib.auth import authenticate
from rest_framework import serializers
from rest_framework.authtoken.models import Token

class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = authenticate(
            username=data['username'],
            password=data['password']
        )

        if not user:
            raise serializers.ValidationError("Invalid Credentials")

        token, _ = Token.objects.get_or_create(user=user)

        # ✅ FIX HERE
        groups = list(user.groups.values_list('name', flat=True))

        role = 'student'
        if 'librarian' in groups:
            role = 'librarian'

        return {
            'token': token.key,
            'username': user.username,
            'user_id': user.id,
            'role': role,
        }
