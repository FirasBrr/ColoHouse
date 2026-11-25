from django.contrib.auth.hashers import make_password
from django.contrib.auth.password_validation import validate_password
from firebase_admin import auth as firebase_auth
from rest_framework import serializers
from .firebase import FirebaseLoginFailed, verify_id_token
from .models import City, RoommateProfile, User


class CitySerializer(serializers.ModelSerializer):
    class Meta:
        model = City
        fields = ['id', 'name', 'region', 'address', 'latitude', 'longitude']


class PublicUserSerializer(serializers.ModelSerializer):
    """What other users can see about someone (no email, no phone)."""
    class Meta:
        model = User
        fields = [
            'id', 'first_name', 'last_name', 'profile_picture', 'bio',
            'institution', 'occupation', 'is_verified',
        ]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])

    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'password']
        extra_kwargs = {
            'first_name': {'required': True, 'allow_blank': False},
            'last_name': {'required': True, 'allow_blank': False},
        }

    def validate_email(self, value):
        value = value.lower()
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class FirebaseLoginSerializer(serializers.Serializer):
    """Login with FirebaseAuth (email/password or Google): Firebase ID token in, our user out.

    first_name / last_name are only used when the account is created
    (Google gives a name, email/password sign-up does not).
    """
    id_token = serializers.CharField(write_only=True)
    first_name = serializers.CharField(required=False, allow_blank=True, max_length=150)
    last_name = serializers.CharField(required=False, allow_blank=True, max_length=150)

    def validate(self, attrs):
        try:
            claims = verify_id_token(attrs['id_token'])
        except firebase_auth.InvalidIdTokenError:
            raise FirebaseLoginFailed()

        uid = claims['uid']
        email = (claims.get('email') or '').lower()
        created = False

        user = User.objects.filter(firebase_uid=uid).first()
        if user is None:
            if not email:
                raise serializers.ValidationError('This Firebase account has no email address.')
            # Only trust the email once Firebase has verified it (Google accounts always are),
            # otherwise anyone could claim someone else's address
            if not claims.get('email_verified', False):
                raise serializers.ValidationError(
                    'Verify your email address (check your inbox), then log in again.'
                )
            user = User.objects.filter(email__iexact=email).first()
            if user is not None:
                self._link(user, uid)
            else:
                user, created = self._create(uid, email, attrs, claims)

        if not user.is_active:
            raise FirebaseLoginFailed('This account is disabled.')
        attrs['user'] = user
        attrs['created'] = created
        return attrs

    def _link(self, user, uid):
        """Existing account (made with the normal register, whose email was never checked):
        Firebase just proved who owns the email, so it is linked to this Firebase account and its
        old Django password is removed. Otherwise whoever registered the email first could still
        log in with /auth/login/. CHECK_REVOKE_TOKEN also kills the tokens issued with that password."""
        if user.firebase_uid:
            raise serializers.ValidationError('This email is already linked to another Firebase account.')
        user.firebase_uid = uid
        user.set_unusable_password()
        user.save(update_fields=['firebase_uid', 'password'])

    def _create(self, uid, email, attrs, claims):
        first_name = attrs.get('first_name', '').strip()
        last_name = attrs.get('last_name', '').strip()
        if not first_name and not last_name and claims.get('name'):
            first_name, _, last_name = claims['name'].strip().partition(' ')
        return User.objects.get_or_create(
            firebase_uid=uid,
            defaults={
                'email': email,
                'first_name': first_name[:150],
                'last_name': last_name.strip()[:150],
                'password': make_password(None),
            },
        )


class ProfileSerializer(serializers.ModelSerializer):
    city = CitySerializer(read_only=True)
    city_id = serializers.PrimaryKeyRelatedField(
        queryset=City.objects.all(),
        source='city',
        write_only=True,
        allow_null=True,
        required=False,
    )

    class Meta:
        model = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'phone',
            'profile_picture', 'bio',
            'institution', 'occupation', 'city', 'city_id',
            'is_verified',
            'push_enabled', 'notify_requests', 'notify_messages',
            'date_joined',
        ]
        read_only_fields = ['id', 'email', 'date_joined', 'is_verified']
        extra_kwargs = {
            'first_name': {'allow_blank': False},
            'last_name': {'allow_blank': False},
        }

    def validate_profile_picture(self, value):
        if value and value.size > 5 * 1024 * 1024:
            raise serializers.ValidationError('The picture must be smaller than 5 MB.')
        return value


class PreferencesSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoommateProfile
        fields = [
            'budget', 'preferred_room_type', 'move_in_date',
            'max_distance_to_center',
            'sleep_schedule', 'noise_tolerance', 'cleanliness',
            'smoker', 'accepts_smokers', 'looking_for_room',
            'updated_at',
        ]
        read_only_fields = ['updated_at']