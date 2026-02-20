from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .serializers import LoginSerializer


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    return Response(serializer.validated_data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout_view(request):
    if hasattr(request.user, "auth_token"):
        request.user.auth_token.delete()
    return Response({"detail": "Logged out successfully."}, status=status.HTTP_200_OK)
