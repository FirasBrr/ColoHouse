from .models import NotificationType

# (title, body) per notification type and language. {sender}, {owner}, {listing}, {text} are filled in by notify()
TEXTS = {
    NotificationType.HOUSING_REQUEST: {
        'en': ('New housing request', '{sender} wants to rent "{listing}".'),
        'fr': ('Nouvelle demande de logement', '{sender} souhaite louer « {listing} ».'),
        'ar': ('طلب سكن جديد', '{sender} يرغب في استئجار «{listing}».'),
    },
    NotificationType.REQUEST_ACCEPTED: {
        'en': ('Request accepted', '{owner} accepted your request for "{listing}". You can now chat.'),
        'fr': ('Demande acceptée', '{owner} a accepté votre demande pour « {listing} ». Vous pouvez maintenant discuter.'),
        'ar': ('تم قبول الطلب', 'قبل {owner} طلبك لـ«{listing}». يمكنكما الآن الدردشة.'),
    },
    NotificationType.REQUEST_DECLINED: {
        'en': ('Request declined', '{owner} declined your request for "{listing}".'),
        'fr': ('Demande refusée', '{owner} a refusé votre demande pour « {listing} ».'),
        'ar': ('تم رفض الطلب', 'رفض {owner} طلبك لـ«{listing}».'),
    },
    NotificationType.NEW_MESSAGE: {
        'en': ('New message from {sender}', '{text}'),
        'fr': ('Nouveau message de {sender}', '{text}'),
        'ar': ('رسالة جديدة من {sender}', '{text}'),
    },
}

SOMEONE = {'en': 'Someone', 'fr': 'Quelqu’un', 'ar': 'شخص ما'}


def render(notification_type, language, **values):
    """Returns (title, body) in the user's language (English if the language is unknown)."""
    texts = TEXTS[notification_type]
    title, body = texts.get(language) or texts['en']
    return title.format(**values), body.format(**values)


def display_name(user, language):
    """First name shown to the other person (never the email)."""
    return user.first_name.strip() or SOMEONE.get(language, SOMEONE['en'])
