from django.db import migrations


def create_conversations(apps, schema_editor):
    """Requests accepted before the chat existed get their conversation too
    (the Firestore document is created when the chat is first opened)."""
    HousingRequest = apps.get_model('housing', 'HousingRequest')
    Conversation = apps.get_model('chat', 'Conversation')
    accepted = HousingRequest.objects.filter(status__in=['accepted', 'completed'], conversation__isnull=True)
    Conversation.objects.bulk_create([Conversation(request=request) for request in accepted])


class Migration(migrations.Migration):

    dependencies = [
        ('chat', '0001_initial'),
        ('housing', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(create_conversations, migrations.RunPython.noop),
    ]
