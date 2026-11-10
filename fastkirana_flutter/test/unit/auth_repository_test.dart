import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fastminute_flutter/data/repositories/auth_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  group('AuthRepository phone extraction & OTP routing', () {
    test('extractIndianPhoneDigits normalizes valid 10, +91, 91, and 0-prefixed numbers', () {
      expect(AuthRepository.extractIndianPhoneDigits('7054470303'), '7054470303');
      expect(AuthRepository.extractIndianPhoneDigits('+91 70544-70303'), '7054470303');
      expect(AuthRepository.extractIndianPhoneDigits('917054470303'), '7054470303');
      expect(AuthRepository.extractIndianPhoneDigits('09170942500'), '9170942500');
    });

    test('extractIndianPhoneDigits rejects emails and invalid numbers', () {
      expect(AuthRepository.extractIndianPhoneDigits('admin@fastkirana.com'), isNull);
      expect(AuthRepository.extractIndianPhoneDigits('12345'), isNull);
      expect(AuthRepository.extractIndianPhoneDigits('5123456789'), isNull);
    });

    test('sendOtp falls back to /api/auth/otp/send when Supabase is uninitialized', () async {
      final dio = _MockDio();
      final repo = AuthRepository(dio);

      when(() => dio.post('/api/auth/otp/send', data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/send'),
          statusCode: 200,
          data: {'success': true},
        ),
      );

      final res = await repo.sendOtp('7054470303');
      expect(res.success, isTrue);
      verify(() => dio.post('/api/auth/otp/send', data: {
            'phone': '7054470303',
            'email': '7054470303',
          })).called(1);
    });

    test('verifyOtp falls back to /api/auth/otp/verify and parses canonical User session', () async {
      final dio = _MockDio();
      final repo = AuthRepository(dio);

      when(() => dio.post('/api/auth/otp/verify', data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
          statusCode: 200,
          data: {
            'token': 'jwt_123',
            'user': {
              'id': 'cmqgzqeud0000vkid7hd6mti4',
              'phone': '+917054470303',
              'email': 'admin@fastkirana.com',
              'role': 'ADMIN',
            },
          },
        ),
      );

      final res = await repo.verifyOtp('7054470303', '123456');
      expect(res.success, isTrue);
      expect(res.token, 'jwt_123');
      expect(res.user?.id, 'cmqgzqeud0000vkid7hd6mti4');
      expect(res.user?.role, 'ADMIN');
    });
  });
}
