from rest_framework import permissions


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Everyone logged in can read a listing, only its owner can edit it."""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user
