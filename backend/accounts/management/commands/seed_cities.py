from django.core.management.base import BaseCommand
from accounts.models import City

CITIES = [
    ('Tunis', 'Tunis', 36.8065, 10.1815),
    ('Ariana', 'Ariana', 36.8665, 10.1647),
    ('Ben Arous', 'Ben Arous', 36.7531, 10.2189),
    ('La Marsa', 'Tunis', 36.8782, 10.3247),
    ('Manouba', 'Manouba', 36.8101, 10.0956),
    ('Bizerte', 'Bizerte', 37.2744, 9.8739),
    ('Nabeul', 'Nabeul', 36.4561, 10.7376),
    ('Sousse', 'Sousse', 35.8256, 10.6360),
    ('Monastir', 'Monastir', 35.7643, 10.8113),
    ('Kairouan', 'Kairouan', 35.6781, 10.0963),
    ('Sfax', 'Sfax', 34.7406, 10.7603),
    ('Gabes', 'Gabes', 33.8815, 10.0982),
]


class Command(BaseCommand):
    help = 'Adds the main cities (safe to run more than once).'

    def handle(self, *args, **options):
        created = 0
        for name, region, latitude, longitude in CITIES:
            _, is_new = City.objects.get_or_create(
                name=name,
                defaults={'region': region, 'latitude': latitude, 'longitude': longitude},
            )
            created += is_new
        self.stdout.write(self.style.SUCCESS(f'{created} city(ies) added, {City.objects.count()} in total.'))
