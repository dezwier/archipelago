"""
Custom exceptions for the application.
"""


class ArchipelagoException(Exception):
    """Base exception for all Archipelago application exceptions."""
    pass


class ValidationError(ArchipelagoException):
    """Raised when validation fails."""
    pass


class NotFoundError(ArchipelagoException):
    """Raised when a requested resource is not found."""
    pass


class ConflictError(ArchipelagoException):
    """Raised when there's a conflict (e.g., duplicate entry)."""
    pass


class AuthenticationError(ArchipelagoException):
    """Raised when authentication fails."""
    pass


class AuthorizationError(ArchipelagoException):
    """Raised when authorization fails."""
    pass

