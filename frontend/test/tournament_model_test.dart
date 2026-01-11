import 'package:flutter_test/flutter_test.dart';
import 'package:clash_companion/models/tournament.dart';

void main() {
  group('Tournament model', () {
    test('fromJson parses all fields', () {
      final json = {
        'tournamentId': 'spring-1',
        'name': 'Spring Clash Cup',
        'nameKeySecondary': 'Mid Madness',
        'nameKey': 'spring_clash',
        'startTime': '2026-02-01T10:00:00Z',
        'registrationTime': '2026-01-28T10:00:00Z',
        'region': 'NA',
        'status': 'upcoming',
        'themeId': 5,
        'schedule': [
          {'startTime': 1234}
        ],
      };

      final model = Tournament.fromJson(json);

      expect(model.tournamentId, 'spring-1');
      expect(model.name, 'Spring Clash Cup');
      expect(model.nameKeySecondary, 'Mid Madness');
      expect(model.nameKey, 'spring_clash');
      expect(model.startTime, '2026-02-01T10:00:00Z');
      expect(model.registrationTime, '2026-01-28T10:00:00Z');
      expect(model.region, 'NA');
      expect(model.status, 'upcoming');
      expect(model.themeId, 5);
      expect(model.schedule, isNotNull);
      expect(model.schedule!.length, 1);
    });

    test('toJson omits nulls and preserves values', () {
      final model = Tournament(
        tournamentId: 'fall-2',
        name: 'Fall Clash',
        startTime: '2026-10-10T12:00:00Z',
        registrationTime: '2026-10-01T12:00:00Z',
        region: 'EU',
        status: 'active',
        themeId: 7,
        schedule: const [],
      );

      final json = model.toJson();

      expect(json['tournamentId'], 'fall-2');
      expect(json['name'], 'Fall Clash');
      expect(json['startTime'], '2026-10-10T12:00:00Z');
      expect(json['registrationTime'], '2026-10-01T12:00:00Z');
      expect(json['region'], 'EU');
      expect(json['status'], 'active');
      expect(json['themeId'], 7);
      expect(json['schedule'], isEmpty);
      expect(json.containsKey('nameKey'), isFalse);
      expect(json.containsKey('nameKeySecondary'), isFalse);
    });
  });

  group('RegistrationPayload', () {
    test('toJson includes only provided fields', () {
      final payload = RegistrationPayload(
        playerId: 'user-123',
        preferredRoles: const ['top', 'mid'],
        availability: 'all_in',
        teamId: 'team-1',
      );

      final json = payload.toJson();

      expect(json['playerId'], 'user-123');
      expect(json['preferredRoles'], ['top', 'mid']);
      expect(json['availability'], 'all_in');
      expect(json['teamId'], 'team-1');
    });

    test('toJson omits optional nulls', () {
      final payload = RegistrationPayload(playerId: 'user-456');
      final json = payload.toJson();

      expect(json, equals({'playerId': 'user-456'}));
    });
  });
}
