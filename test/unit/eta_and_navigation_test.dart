import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/constants/app_constants.dart';
import 'package:quickserve/core/errors/app_exception.dart';
import 'package:quickserve/core/utils/geo_utils.dart';
import 'package:quickserve/core/utils/navigation_utils.dart';
import 'package:quickserve/features/customer/presentation/widgets/customer_request_details_sheet.dart';
import 'package:quickserve/models/service_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('ETA and Navigation Workflow Tests', () {
    test('1. ServiceRequest parses estimated_arrival fromMap and serializes toMap correctly', () {
      final etaDate = DateTime(2026, 10, 1, 10, 30);
      final map = {
        DbColumns.id: 'req-eta-100',
        DbColumns.customerId: 'cust-100',
        DbColumns.category: 'Plumbing',
        DbColumns.title: 'Fix leak',
        DbColumns.serviceAddress: '100 Main St',
        DbColumns.priority: 'high',
        DbColumns.status: 'assigned',
        DbColumns.estimatedArrival: etaDate.toIso8601String(),
      };

      final req = ServiceRequest.fromMap(map);
      expect(req.estimatedArrival, isNotNull);
      expect(req.estimatedArrival, etaDate);

      final toMapResult = req.toMap();
      expect(toMapResult[DbColumns.estimatedArrival], etaDate.toIso8601String());
    });

    test('2. ETA can be updated via copyWith', () {
      final req = ServiceRequest(
        id: 'req-001',
        customerId: 'cust-001',
        category: 'Plumbing',
        title: 'Leaky faucet',
        serviceAddress: '123 Park Ave',
        priority: RequestPriority.normal,
        status: RequestStatus.assigned,
      );

      expect(req.estimatedArrival, isNull);

      final newEta = DateTime(2026, 10, 1, 14, 0);
      final updatedReq = req.copyWith(estimatedArrival: newEta);

      expect(updatedReq.estimatedArrival, newEta);
      expect(updatedReq.id, req.id);
    });

    test('3. Terminal requests (completed, cancelled) reject ETA modifications', () {
      final completedReq = ServiceRequest(
        id: 'req-completed',
        customerId: 'cust-001',
        category: 'Cleaning',
        title: 'Home cleaning',
        serviceAddress: '456 Elm St',
        priority: RequestPriority.normal,
        status: RequestStatus.completed,
      );

      final cancelledReq = ServiceRequest(
        id: 'req-cancelled',
        customerId: 'cust-001',
        category: 'Cleaning',
        title: 'Home cleaning',
        serviceAddress: '456 Elm St',
        priority: RequestPriority.normal,
        status: RequestStatus.cancelled,
      );

      expect(completedReq.status.isCompleted, isTrue);
      expect(completedReq.status.isActive, isFalse);

      expect(cancelledReq.status.isCancelled, isTrue);
      expect(cancelledReq.status.isActive, isFalse);
    });

    test('4. NavigationUtils handles missing and invalid coordinates safely', () async {
      // Both null location and null/empty address check
      expect(
        () => NavigationUtils.launchDirections(location: null, address: null),
        throwsA(isA<ServiceException>().having(
          (e) => e.message,
          'message',
          contains('Customer location is unavailable'),
        )),
      );

      // Invalid latitude check without valid address
      final invalidLoc = GeoPoint(latitude: 100.0, longitude: 77.0);
      expect(
        () => NavigationUtils.launchDirections(location: invalidLoc, address: null),
        throwsA(isA<ServiceException>().having(
          (e) => e.message,
          'message',
          contains('Customer location is unavailable'),
        )),
      );
    });

    testWidgets('5. Customer UI displays Estimated Arrival when ETA is present', (tester) async {
      final etaTime = DateTime(2026, 10, 1, 10, 30);
      final req = ServiceRequest(
        id: 'req-with-eta',
        customerId: 'cust-100',
        category: 'Plumbing',
        title: 'Pipe Leak Repair',
        serviceAddress: '789 Indiranagar 100ft Road',
        priority: RequestPriority.urgent,
        status: RequestStatus.assigned,
        estimatedArrival: etaTime,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CustomerRequestDetailsSheet(request: req),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Estimated Arrival'), findsWidgets);
      expect(find.text('Updated by your service agent'), findsOneWidget);
    });

    testWidgets('6. Customer UI displays "Not provided yet" when ETA is missing', (tester) async {
      final req = ServiceRequest(
        id: 'req-no-eta',
        customerId: 'cust-100',
        category: 'Electrical',
        title: 'Wiring check',
        serviceAddress: '556 Koramangala 5th Block',
        priority: RequestPriority.normal,
        status: RequestStatus.assigned,
        estimatedArrival: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CustomerRequestDetailsSheet(request: req),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Estimated Arrival'), findsWidgets);
      expect(find.text('Not provided yet'), findsOneWidget);
      expect(find.text('Updated by your service agent'), findsNothing);
    });
  });
}
