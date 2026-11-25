from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .models import City, RoommateProfile, User
from .serializers import (
    CitySerializer,
    FirebaseLoginSerializer,
    PreferencesSerializer,
    ProfileSerializer,
    RegisterSerializer,
)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class FirebaseLoginView(generics.GenericAPIView):
    """FirebaseAuth login: the app sends its Firebase ID token, we answer with our own JWT pair
    (same response as /auth/login/), so the rest of the API works exactly the same."""
    serializer_class = FirebaseLoginSerializer
    permission_classes = [permissions.AllowAny]
    # Ignore any old/expired "Authorization: Bearer" header the app may still send
    authentication_classes = []

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        created = serializer.validated_data['created']
        refresh = RefreshToken.for_user(user)
        return Response(
            {'access': str(refresh.access_token), 'refresh': str(refresh), 'created': created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class MeView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProfileSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class PreferencesView(generics.RetrieveUpdateAPIView):
    serializer_class = PreferencesSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        profile, _ = RoommateProfile.objects.get_or_create(user=self.request.user)
        return profile


class CityListView(generics.ListAPIView):
    queryset = City.objects.all()
    serializer_class = CitySerializer
    permission_classes = [permissions.AllowAny]
