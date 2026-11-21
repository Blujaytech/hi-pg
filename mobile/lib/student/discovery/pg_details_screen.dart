import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_models.dart';
import '../../auth/auth_state.dart';
import '../../auth/auth_widgets.dart';
import '../../auth/google_owner_conflict.dart';
import '../../auth/google_student_sign_in.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/api_client.dart';
import '../../shared/app_states.dart';
import '../booking/booking_repository.dart';
import '../booking/booking_models.dart';
import '../payment/payment_repository.dart';
import '../payment/payment_choice_sheet.dart';
import '../payment/direct_payment_repository.dart';
import '../payment/razorpay_checkout.dart';
import '../profile/customer_profile_repository.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';
import 'property_location.dart';

enum _GuestSignInChoice { google, mobile }

/// PG details with live bed availability. Guests (reached via `/explore`)
/// can see everything; signing in is only asked for when they book a bed,
/// after which booking resumes for the bed they picked.
class PgDetailsScreen extends StatefulWidget {
  final String pgId;
  final BookingType? preferredBookingType;

  const PgDetailsScreen({
    super.key,
    required this.pgId,
    this.preferredBookingType,
  });

  @override
  State<PgDetailsScreen> createState() => _PgDetailsScreenState();
}

class _PgDetailsScreenState extends State<PgDetailsScreen> {
  final _repository = DiscoveryRepository();
  final _bookingRepository = BookingRepository();
  final _paymentRepository = PaymentRepository();
  final _directPaymentRepository = DirectPaymentRepository();
  final _profileRepository = CustomerProfileRepository();
  late final RazorpayCheckout _checkout;
  late Future<PgDetails> _future;
  late final AuthState _auth;

  StreamSubscription<Map<String, dynamic>>? _availabilitySubscription;
  int? _liveAvailableBeds;
  int? _liveTotalBeds;
  bool _live = false;
  bool _booking = false;
  bool _googleSignInInProgress = false;
  bool _registeringInterest = false;
  bool _interestRegistered = false;
  BookingType? _selectedBookingType;
  late DateTime _selectedCheckIn;
  DateTime? _selectedCheckOut;

  /// Bed a guest chose before signing in; booked once they are back.
  AvailableBedOption? _pendingBed;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>()..addListener(_resumeAfterSignIn);
    _checkout = RazorpayCheckout(_paymentRepository);
    final now = DateTime.now();
    _selectedCheckIn = DateTime(now.year, now.month, now.day);
    _selectedBookingType = widget.preferredBookingType;
    _selectedCheckOut = _selectedBookingType == BookingType.dayWise
        ? _selectedCheckIn.add(const Duration(days: 1))
        : null;
    _loadDetails();
    _subscribeToLiveAvailability();
  }

  void _resumeAfterSignIn() {
    final bed = _pendingBed;
    if (bed == null ||
        _googleSignInInProgress ||
        _auth.status != AuthStatus.authenticated) {
      return;
    }
    _pendingBed = null;
    // Let the sign-in screen finish closing before opening the date picker.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _bookBed(bed);
    });
  }

  Future<void> _askToSignIn(AvailableBedOption bed) async {
    final choice = await showModalBottomSheet<_GuestSignInChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign in to book ${bed.label}',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                "Choose Google for the quickest checkout, or continue with your mobile number. You'll return here to confirm the booking.",
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              GoogleStudentButton(
                onPressed: () =>
                    Navigator.pop(sheetContext, _GuestSignInChoice.google),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _GuestSignInChoice.mobile),
                icon: const Icon(Icons.phone_iphone_rounded, size: 19),
                label: const Text('Continue with mobile number'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Keep browsing'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    _pendingBed = bed;
    if (choice == _GuestSignInChoice.google) {
      await _signInWithGoogleForBed();
      return;
    }

    final here = GoRouterState.of(context).uri.toString();
    context.push(Uri(path: '/student/login', queryParameters: {'from': here})
        .toString());
  }

  Future<void> _signInWithGoogleForBed() async {
    final bed = _pendingBed;
    if (bed == null) return;
    var ownerGmail = false;
    var useMobileFallback = false;
    var signedIn = false;
    _googleSignInInProgress = true;
    setState(() => _booking = true);
    try {
      await _auth.googleStudentLogin();
      signedIn = true;
    } on GoogleStudentSignInCanceled {
      if (mounted) {
        useMobileFallback = await _showGoogleSignInCanceled();
      }
      if (!useMobileFallback) _pendingBed = null;
    } on GoogleStudentSignInFailure catch (error) {
      _pendingBed = null;
      if (mounted) {
        await _showGoogleSignInError(error.message);
      }
    } on ApiException catch (error) {
      _pendingBed = null;
      if (isOwnerGmailConflict(error)) {
        ownerGmail = true;
      } else if (mounted) {
        await _showGoogleSignInError(error.message);
      }
    } catch (_) {
      _pendingBed = null;
      if (mounted) {
        await _showGoogleSignInError(
            'Google sign-in could not be completed. Please try again.');
      }
    } finally {
      _googleSignInInProgress = false;
      if (mounted) setState(() => _booking = false);
    }
    if (!mounted) return;
    if (signedIn) {
      // Resume explicitly after the native Google account sheet has closed.
      // Relying only on AuthState's synchronous listener races with the
      // router refresh and can lose the selected bed before the profile gate
      // opens.
      _pendingBed = null;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _bookBed(bed);
      return;
    }
    if (ownerGmail) await _resolveOwnerGmail(bed);
    if (useMobileFallback && mounted) {
      final here = GoRouterState.of(context).uri.toString();
      context.push(Uri(path: '/student/login', queryParameters: {'from': here})
          .toString());
    }
  }

  Future<bool> _showGoogleSignInCanceled() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Google sign-in didn't finish"),
            content: const Text(
              'Google did not return an account to the app. Try Google again, '
              'or continue securely with your mobile number to book the '
              'selected bed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Use mobile number'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showGoogleSignInError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Google sign-in failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// The chosen Gmail already belongs to a PG owner, so the server won't make
  /// it a customer account. Offer a different Google account or the mobile
  /// number, and keep the chosen bed either way.
  Future<void> _resolveOwnerGmail(AvailableBedOption bed) async {
    final choice = await showOwnerGmailConflict(context);
    if (choice == null || !mounted) return;
    _pendingBed = bed;
    if (choice == OwnerGmailChoice.anotherGoogleAccount) {
      // Forget the owner account so Google shows its account picker again.
      await GoogleStudentSignIn.instance.signOut();
      if (mounted) await _signInWithGoogleForBed();
      return;
    }
    final here = GoRouterState.of(context).uri.toString();
    context.push(Uri(path: '/student/login', queryParameters: {'from': here})
        .toString());
  }

  @override
  void dispose() {
    _auth.removeListener(_resumeAfterSignIn);
    _availabilitySubscription?.cancel();
    super.dispose();
  }

  void _loadDetails() {
    _future = _repository.getDetails(
      widget.pgId,
      bookingType: _selectedBookingType?.apiValue,
      checkIn: _selectedBookingType == null ? null : _selectedCheckIn,
      checkOut: _selectedBookingType == BookingType.dayWise
          ? _selectedCheckOut
          : null,
    );
  }

  void _reload() => setState(_loadDetails);

  void _selectBookingType(BookingType type) {
    setState(() {
      _selectedBookingType = type;
      _selectedCheckOut = type == BookingType.dayWise
          ? _selectedCheckIn.add(const Duration(days: 1))
          : null;
      _loadDetails();
    });
  }

  Future<void> _chooseAvailabilityDates() async {
    final type = _selectedBookingType;
    if (type == null) return;
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    if (type == BookingType.monthly) {
      final date = await showDatePicker(
        context: context,
        initialDate:
            _selectedCheckIn.isBefore(first) ? first : _selectedCheckIn,
        firstDate: first,
        lastDate: first.add(const Duration(days: 365)),
        helpText: 'Choose monthly move-in date',
      );
      if (date == null || !mounted) return;
      setState(() {
        _selectedCheckIn = date;
        _selectedCheckOut = null;
        _loadDetails();
      });
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _selectedCheckIn.isBefore(first) ? first : _selectedCheckIn,
        end:
            (_selectedCheckOut ?? _selectedCheckIn.add(const Duration(days: 1)))
                    .isAfter(first)
                ? (_selectedCheckOut ??
                    _selectedCheckIn.add(const Duration(days: 1)))
                : first.add(const Duration(days: 1)),
      ),
      helpText: 'Choose day-wise stay dates',
    );
    if (range == null || !mounted) return;
    if (range.duration.inDays > 27) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Day-wise stays can be booked for up to 27 nights.'),
      ));
      return;
    }
    setState(() {
      _selectedCheckIn = range.start;
      _selectedCheckOut = range.end;
      _loadDetails();
    });
  }

  void _subscribeToLiveAvailability() {
    _availabilitySubscription = ApiClient.instance.sseStream(
      '/public/pgs/${widget.pgId}/availability/stream',
      // Without this the "Live" badge stayed lit after the stream died,
      // presenting a stale bed count as up-to-the-second on a screen people
      // book from. The client reconnects on its own; the badge just has to
      // tell the truth in between.
      onConnected: (connected) {
        if (mounted && _live != connected) setState(() => _live = connected);
      },
    ).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _liveAvailableBeds = event['availableBeds'] as int?;
          _liveTotalBeds = event['totalBeds'] as int?;
          _live = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _live = false);
      },
      cancelOnError: false,
    );
  }

  Future<void> _bookBed(AvailableBedOption bed) async {
    if (_auth.status != AuthStatus.authenticated) {
      await _askToSignIn(bed);
      return;
    }
    if (_auth.role != UserRole.student) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Beds are booked from a customer account. Sign in with Google or your mobile number to book.')));
      return;
    }
    var bookingType = _selectedBookingType ??
        (bed.bookingMode == 'DAY_WISE'
            ? BookingType.dayWise
            : BookingType.monthly);
    if (bed.bookingMode == 'FLEXIBLE' && _selectedBookingType == null) {
      final selected = await showModalBottomSheet<BookingType>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('How long are you staying?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: const Text('Monthly'),
                    subtitle: const Text('28 nights or longer'),
                    onTap: () => Navigator.pop(context, BookingType.monthly)),
                ListTile(
                    leading: const Icon(Icons.today_rounded),
                    title: const Text('Day-wise'),
                    subtitle: const Text('1 to 27 nights'),
                    onTap: () => Navigator.pop(context, BookingType.dayWise)),
              ]),
        )),
      );
      if (selected == null || !mounted) return;
      bookingType = selected;
    }

    if (!await _ensureBookingEligible(bookingType) || !mounted) return;

    DateTime? moveInDate;
    DateTime? checkOutDate;
    TimeOfDay? checkOutTime;
    if (_selectedBookingType == bookingType) {
      moveInDate = _selectedCheckIn;
      checkOutDate =
          bookingType == BookingType.dayWise ? _selectedCheckOut : null;
    } else {
      final now = DateTime.now();
      moveInDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 180)),
        helpText: 'Choose a move-in date',
      );
      if (moveInDate == null || !mounted) return;
      if (bookingType == BookingType.dayWise) {
        checkOutDate = await showDatePicker(
          context: context,
          initialDate: moveInDate.add(const Duration(days: 1)),
          firstDate: moveInDate.add(const Duration(days: 1)),
          lastDate: moveInDate.add(const Duration(days: 27)),
          helpText: 'Choose checkout date',
        );
        if (checkOutDate == null || !mounted) return;
      }
    }
    if (bookingType == BookingType.dayWise && checkOutDate == null) {
      return;
    }
    if (bookingType == BookingType.dayWise) {
      checkOutTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 11, minute: 0),
        helpText: 'Choose checkout time',
      );
      if (checkOutTime == null || !mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _BookingReviewDialog(
        bedLabel: bed.label,
        bookingType: bookingType,
        checkIn: moveInDate!,
        checkOut: checkOutDate,
        checkOutTime: checkOutTime,
      ),
    );
    if (confirmed != true || !mounted) return;

    // Re-read immediately before checkout. Direct payment is configured by
    // the owner per PG and may have changed while this details page was open;
    // using the page's original Future made the payment method disappear
    // until the customer manually refreshed or reopened the property.
    final pg = await _repository.getDetails(widget.pgId);
    if (!mounted) return;
    final paymentChoice = await showBookingPaymentChoice(
      context,
      directOwnerAvailable: pg.directPaymentAvailable,
    );
    if (paymentChoice == null || !mounted) return;

    setState(() => _booking = true);
    try {
      final booking = await _bookingRepository.book(
        bedId: bed.id,
        bookingType: bookingType,
        moveInDate: moveInDate,
        checkOutDate: checkOutDate,
        checkOutTime: checkOutTime == null
            ? null
            : '${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      if (paymentChoice == BookingPaymentChoice.online) {
        final order = await _paymentRepository.createBookingOrder(booking.id);
        await _checkout.pay(order,
            description: '${bookingType.label} booking at ${booking.pgName}');
      } else {
        try {
          await _directPaymentRepository.selectDirectPayment(booking.id);
        } catch (error) {
          // The method was available when details loaded but became invalid
          // before selection. Release the untouched hold so it cannot strand
          // the customer behind an overlapping-booking error.
          try {
            await _bookingRepository.cancel(
              booking.id,
              reason: 'Direct owner payment was unavailable',
            );
          } catch (_) {
            // The original payment error remains the useful one. A failed
            // cleanup can still be recovered from My Bookings or hold expiry.
          }
          rethrow;
        }
        if (!mounted) return;
        setState(() => _booking = false);
        final informed = await context
            .push<bool>('/student/bookings/${booking.id}/direct-payment');
        if (!mounted) return;
        if (informed == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment sent for owner verification. The bed is not allocated until approval.'),
            ),
          );
        }
        _reload();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${bed.label} is confirmed and paid.'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.go('/student/bookings'),
          ),
        ),
      );
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 409 &&
            e.message.toLowerCase().contains('overlap')) {
          await _showExistingBookingRecovery();
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _showExistingBookingRecovery() async {
    if (!mounted) return;
    final openBookings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish your existing booking'),
        content: const Text(
          'You already have a booking or payment hold for these dates. Open My Bookings to resume payment or cancel that booking before choosing another bed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open My Bookings'),
          ),
        ],
      ),
    );
    if (openBookings == true && mounted) context.go('/student/bookings');
  }

  Future<bool> _ensureBookingEligible(BookingType bookingType) async {
    setState(() => _booking = true);
    try {
      final eligibility = await _profileRepository.eligibility(bookingType);
      if (!mounted) return false;
      if (eligibility.eligible) return true;

      setState(() => _booking = false);
      final completed = await context.push<bool>(
        Uri(
          path: '/student/profile',
          queryParameters: {
            'requiredFor': bookingType.apiValue,
          },
        ).toString(),
      );
      if (!mounted) return false;
      if (completed == true) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Booking paused. Complete the required profile details to continue.'),
        ),
      );
      return false;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _openRouteInGoogleMaps(String destination) async {
    final uri = propertyDirectionsUri(destination);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Install Google Maps or a browser to start directions.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps could not be opened on this device.'),
        ),
      );
    }
  }

  Future<void> _openGoogleMapsUrl(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Install Google Maps or a browser to open this location.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Google Maps could not be opened on this device.')),
      );
    }
  }

  Future<void> _registerInterest(PgDetails pg) async {
    if (_registeringInterest || _interestRegistered) return;
    if (_auth.status != AuthStatus.authenticated) {
      final here = GoRouterState.of(context).uri.toString();
      context.push(Uri(path: '/student/login', queryParameters: {'from': here})
          .toString());
      return;
    }
    if (_auth.role != UserRole.student) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in with a customer account to notify this PG.'),
      ));
      return;
    }
    setState(() => _registeringInterest = true);
    try {
      await _repository.registerInterest(pg.id);
      if (!mounted) return;
      setState(() => _interestRegistered = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Interest registered. We will notify you when this PG enables booking.'),
      ));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _registeringInterest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'PG details',
        subtitle: 'Photos, rooms, amenities and location',
        bottom: _booking
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: FutureBuilder<PgDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5));
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'This PG could not be loaded right now.';
            return _DetailsError(message: message, onRetry: _reload);
          }

          final pg = snapshot.data!;
          final address = [pg.address, pg.city, pg.state, pg.pincode]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(', ');
          final destination = propertyDestination(
            locationUrl: pg.locationUrl,
            name: pg.name,
            address: pg.address,
            city: pg.city,
            state: pg.state,
            pincode: pg.pincode,
          );
          final availableBeds = _selectedBookingType == null
              ? (_liveAvailableBeds ?? pg.availableBeds)
              : pg.availableBeds;
          final totalBeds = _selectedBookingType == null
              ? (_liveTotalBeds ?? pg.totalBeds)
              : pg.totalBeds;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _PropertyHeader(
                  pg: pg,
                  availableBeds: availableBeds,
                  totalBeds: totalBeds,
                  live: _live,
                ),
                if (pg.description != null &&
                    pg.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('About this property',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 7),
                  Text(pg.description!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.muted)),
                ],
                const SizedBox(height: 26),
                _PropertyLocationSection(
                  latitude: pg.latitude,
                  longitude: pg.longitude,
                  address: address,
                  destination: destination,
                  onOpenMap: () => _openGoogleMapsUrl(
                    propertyMapUri(pg.locationUrl, destination),
                  ),
                  onDirections: () => _openRouteInGoogleMaps(destination),
                ),
                const SizedBox(height: 22),
                if (!pg.verified || !pg.bookingEnabled)
                  _UnverifiedListingCard(
                    working: _registeringInterest,
                    registered: _interestRegistered,
                    onInterested: () => _registerInterest(pg),
                  )
                else ...[
                  _StayAvailabilityControls(
                    selected: _selectedBookingType,
                    checkIn: _selectedCheckIn,
                    checkOut: _selectedCheckOut,
                    onSelect: _selectBookingType,
                    onChangeDates: _chooseAvailabilityDates,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: _BookingStepHeader(
                          step: 2,
                          title: 'Select your bed',
                          subtitle:
                              'Open a floor or block and choose an available bed.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${pg.floors.length} floor/block${pg.floors.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (pg.floors.isEmpty)
                    const _NoRoomsState()
                  else
                    for (var index = 0; index < pg.floors.length; index++) ...[
                      _FloorCard(
                        floor: pg.floors[index],
                        initiallyExpanded: false,
                        booking: _booking,
                        onBookBed: _bookBed,
                      ),
                      if (index != pg.floors.length - 1)
                        const SizedBox(height: 12),
                    ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UnverifiedListingCard extends StatelessWidget {
  final bool working;
  final bool registered;
  final VoidCallback onInterested;

  const _UnverifiedListingCard({
    required this.working,
    required this.registered,
    required this.onInterested,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Icon(Icons.shield_outlined, color: Color(0xFFB76A00)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Owner verification pending',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            const Text(
              'This listing can be viewed, but rooms, beds, online booking and payments stay hidden until the owner completes KYC and hi pg approves the property.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: working || registered ? null : onInterested,
              icon: working
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(registered
                      ? Icons.check_circle_outline_rounded
                      : Icons.notifications_active_outlined),
              label: Text(registered
                  ? 'Owner notification requested'
                  : "I'm interested — notify owner"),
            ),
            const SizedBox(height: 7),
            const Text(
              'No payment can be made through hi pg for this listing yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _StayAvailabilityControls extends StatelessWidget {
  final BookingType? selected;
  final DateTime checkIn;
  final DateTime? checkOut;
  final ValueChanged<BookingType> onSelect;
  final VoidCallback onChangeDates;

  const _StayAvailabilityControls({
    required this.selected,
    required this.checkIn,
    required this.checkOut,
    required this.onSelect,
    required this.onChangeDates,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = selected == null
        ? 'Select a stay type to see matching rooms and beds'
        : selected == BookingType.monthly
            ? 'Move in ${DateFormat('d MMM yyyy').format(checkIn)}'
            : '${DateFormat('d MMM').format(checkIn)} – '
                '${DateFormat('d MMM yyyy').format(checkOut!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BookingStepHeader(
              step: 1,
              title: 'Choose your stay',
              subtitle: 'Select a booking mode and confirm your dates.',
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: selected == BookingType.monthly,
                  onSelected: (_) => onSelect(BookingType.monthly),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Day-wise'),
                  selected: selected == BookingType.dayWise,
                  onSelected: (_) => onSelect(BookingType.dayWise),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: selected == null ? null : onChangeDates,
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: Text(dateLabel, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingStepHeader extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;

  const _BookingStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingReviewDialog extends StatelessWidget {
  final String bedLabel;
  final BookingType bookingType;
  final DateTime checkIn;
  final DateTime? checkOut;
  final TimeOfDay? checkOutTime;

  const _BookingReviewDialog({
    required this.bedLabel,
    required this.bookingType,
    required this.checkIn,
    required this.checkOut,
    required this.checkOutTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: const _BookingStepHeader(
        step: 3,
        title: 'Review your booking',
        subtitle: 'Confirm these details before choosing payment.',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BookingReviewRow(label: 'Bed', value: bedLabel),
          _BookingReviewRow(label: 'Stay', value: bookingType.label),
          _BookingReviewRow(
            label: 'Check-in',
            value: dateFormat.format(checkIn),
          ),
          if (checkOut != null)
            _BookingReviewRow(
              label: 'Checkout',
              value: '${dateFormat.format(checkOut!)}'
                  '${checkOutTime == null ? '' : ' · ${checkOutTime!.format(context)}'}',
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: AppRadii.small,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.timer_outlined,
                    size: 18, color: AppColors.brandText),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Continuing creates a temporary bed hold. Confirmation happens only after payment verification.',
                    style: TextStyle(
                      color: AppColors.brandText,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Go back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Choose payment'),
        ),
      ],
    );
  }
}

class _BookingReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _BookingReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyHeader extends StatelessWidget {
  final PgDetails pg;
  final int availableBeds;
  final int totalBeds;
  final bool live;

  const _PropertyHeader({
    required this.pg,
    required this.availableBeds,
    required this.totalBeds,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrls = <String>{
      if (pg.photoUrl != null) pg.photoUrl!,
      ...pg.photos.map((photo) => photo.url),
    }.toList();
    final monthlyRents = pg.floors
        .expand((floor) => floor.rooms)
        .map((room) => room.rentPerBed)
        .where((rent) => rent > 0)
        .toList();
    final minimumMonthlyRent = monthlyRents.isEmpty
        ? null
        : monthlyRents
            .reduce((current, next) => current < next ? current : next);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadii.large,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'pg-image-${pg.id}',
                  child: photoUrls.isNotEmpty
                      ? Image.network(
                          photoUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _DetailsPlaceholder(),
                        )
                      : const _DetailsPlaceholder(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                      stops: [.52, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: pg.verified
                          ? AppColors.success.withValues(alpha: .94)
                          : AppColors.warning.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pg.verified
                              ? Icons.verified_rounded
                              : Icons.shield_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pg.verified ? 'Verified property' : 'Unverified',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (photoUrls.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: .68),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => _PgGalleryViewer(
                              pgName: pg.name,
                              photoUrls: photoUrls,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined,
                                  size: 15, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Photos ${photoUrls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pg.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.white.withValues(alpha: .72)),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${pg.address}, ${pg.city}${pg.state != null ? ', ${pg.state}' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                if (minimumMonthlyRent != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Rooms from ${_rupees.format(minimumMonthlyRent)}/month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _HeaderMetric(
                        label: 'Stay type',
                        value: pg.genderPreference.label,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (pg.verified)
                      Expanded(
                        child: _HeaderMetric(
                          label: live ? 'Live availability' : 'Availability',
                          value: '$availableBeds of $totalBeds beds',
                          accent: availableBeds > 0
                              ? AppColors.successBright
                              : Colors.white.withValues(alpha: .6),
                        ),
                      )
                    else
                      const Expanded(
                        child: _HeaderMetric(
                          label: 'Booking status',
                          value: 'Not enabled',
                          accent: Color(0xFFFBBF24),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPlaceholder extends StatelessWidget {
  const _DetailsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.inkSoft,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, color: Colors.white70, size: 52),
            SizedBox(height: 8),
            Text(
              'Property photos coming soon',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PgGalleryViewer extends StatefulWidget {
  final String pgName;
  final List<String> photoUrls;

  const _PgGalleryViewer({required this.pgName, required this.photoUrls});

  @override
  State<_PgGalleryViewer> createState() => _PgGalleryViewerState();
}

class _PgGalleryViewerState extends State<_PgGalleryViewer> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.pgName),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(
                '${_index + 1}/${widget.photoUrls.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.photoUrls[index],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _HeaderMetric({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent == Colors.white
                  ? Colors.white.withValues(alpha: .72)
                  : accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyLocationSection extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String address;
  final String destination;
  final VoidCallback onOpenMap;
  final VoidCallback onDirections;

  const _PropertyLocationSection({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.destination,
    required this.onOpenMap,
    required this.onDirections,
  });

  @override
  State<_PropertyLocationSection> createState() =>
      _PropertyLocationSectionState();
}

class _PropertyLocationSectionState extends State<_PropertyLocationSection> {
  PropertyCoordinates? _coordinates;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude != null && longitude != null) {
      _coordinates = PropertyCoordinates(latitude, longitude);
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    final coordinates = await geocodeProperty(widget.destination);
    if (!mounted) return;
    setState(() {
      _coordinates = coordinates;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = _coordinates;
    if (coordinates != null) {
      return _LocationSection(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        address: widget.address,
        onOpenMap: widget.onOpenMap,
        onDirections: widget.onDirections,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(widget.address, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_resolving)
                const CircularProgressIndicator(strokeWidth: 2.5)
              else
                const Icon(Icons.map_rounded, size: 44, color: AppColors.brand),
              const SizedBox(height: 12),
              Text(
                _resolving
                    ? 'Loading the property map...'
                    : 'Google Maps has the property location',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (!_resolving) ...[
                const SizedBox(height: 4),
                TextButton(onPressed: _resolve, child: const Text('Retry map')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LocationActions(
          onOpenMap: widget.onOpenMap,
          onDirections: widget.onDirections,
        ),
      ],
    );
  }
}

class _LocationSection extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;
  final VoidCallback onOpenMap;
  final VoidCallback onDirections;

  const _LocationSection({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.onOpenMap,
    required this.onDirections,
  });

  @override
  State<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<_LocationSection> {
  GoogleMapController? _controller;

  LatLng get _point => LatLng(widget.latitude, widget.longitude);

  Future<void> _recenter() async {
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _point, zoom: 16.8),
      ),
    );
  }

  Future<void> _zoomIn() async {
    await _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    await _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(widget.address, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _point,
                  zoom: 16.8,
                ),
                onMapCreated: (controller) => _controller = controller,
                markers: {
                  Marker(
                    markerId: const MarkerId('property'),
                    position: _point,
                    infoWindow: InfoWindow(
                      title: 'Property location',
                      snippet: widget.address,
                    ),
                  ),
                },
                mapType: MapType.normal,
                // Use the full Android renderer. Lite mode can create a map
                // surface while leaving its tiles blank on some devices.
                liteModeEnabled: false,
                buildingsEnabled: true,
                indoorViewEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                minMaxZoomPreference: const MinMaxZoomPreference(4, 21),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: AppColors.ink, size: 16),
                      SizedBox(width: 6),
                      Text('Exact property location',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _MapControl(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onTap: _zoomIn),
                    const SizedBox(height: 7),
                    _MapControl(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onTap: _zoomOut),
                    const SizedBox(height: 7),
                    _MapControl(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Recenter property',
                      onTap: _recenter,
                      highlighted: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LocationActions(
          onOpenMap: widget.onOpenMap,
          onDirections: widget.onDirections,
        ),
      ],
    );
  }
}

class _LocationActions extends StatelessWidget {
  final VoidCallback onOpenMap;
  final VoidCallback onDirections;

  const _LocationActions({
    required this.onOpenMap,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('View map'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Enroute'),
          ),
        ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _MapControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.ink : Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 21,
              color: highlighted ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorCard extends StatelessWidget {
  final FloorAvailability floor;
  final bool initiallyExpanded;
  final bool booking;
  final ValueChanged<AvailableBedOption> onBookBed;

  const _FloorCard({
    required this.floor,
    required this.initiallyExpanded,
    required this.booking,
    required this.onBookBed,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        floor.rooms.fold<int>(0, (sum, room) => sum + room.availableBeds);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
        collapsedShape: const Border(),
        shape: const Border(),
        title: Text(
          'Floor/Block · ${floor.name}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          '${floor.rooms.length} room${floor.rooms.length == 1 ? '' : 's'} · $available beds available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          if (floor.rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No rooms are available on this floor yet.'),
            )
          else
            for (var index = 0; index < floor.rooms.length; index++) ...[
              _RoomCard(
                  room: floor.rooms[index],
                  booking: booking,
                  onBookBed: onBookBed),
              if (index != floor.rooms.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class _RoomCard extends StatelessWidget {
  final RoomAvailability room;
  final bool booking;
  final ValueChanged<AvailableBedOption> onBookBed;

  const _RoomCard(
      {required this.room, required this.booking, required this.onBookBed});

  @override
  Widget build(BuildContext context) {
    final available = room.availableBeds > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room ${room.roomNumber}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${room.sharingCount}-sharing · ${room.roomType == 'AC' ? 'Air conditioned' : 'Non-AC'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _rupees.format(room.rentPerBed),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.ink),
                  ),
                  Text('per bed / month',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10)),
                  if (room.dayWiseRate != null &&
                      room.bookingMode != 'MONTHLY') ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_rupees.format(room.dayWiseRate)} / day',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.brandText),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: available ? AppColors.successSoft : AppColors.fill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bed_rounded,
                    size: 16,
                    color: available ? AppColors.success : AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  available
                      ? '${room.availableBeds} of ${room.sharingCount} beds available'
                      : 'No beds available',
                  style: TextStyle(
                    color: available ? AppColors.success : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (room.beds.isNotEmpty) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    available ? 'Select a bed' : 'Beds',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const _SeatLegend(),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final itemWidth = (constraints.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final seat in room.beds)
                      SizedBox(
                        width: itemWidth,
                        child: _BedSeatTile(
                          seat: seat,
                          onTap: booking || seat.option == null
                              ? null
                              : () => onBookBed(seat.option!),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One bed in the room's bed map. Free beds are outlined in green and can be
/// tapped to book; taken beds are greyed out, like a sold-out seat, and keep
/// their label so the room's layout stays readable.
class _BedSeatTile extends StatelessWidget {
  final BedSeat seat;
  final VoidCallback? onTap;

  const _BedSeatTile({required this.seat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final free = seat.available;
    final foreground = free ? AppColors.success : AppColors.subtle;
    return Semantics(
      button: free,
      enabled: onTap != null,
      label: '${seat.label}, ${free ? 'available' : 'taken'}',
      child: ExcludeSemantics(
        child: Material(
          color: free ? AppColors.surface : AppColors.fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: free ? AppColors.successBright : AppColors.border,
              width: free ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    free ? Icons.bed_outlined : Icons.bed_rounded,
                    size: 17,
                    color: foreground,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: free ? AppColors.success : AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: free ? null : TextDecoration.lineThrough,
                      decorationColor: AppColors.subtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    Widget key(Color fill, Color border, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: border, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key(AppColors.surface, AppColors.successBright, 'Free'),
        const SizedBox(width: 12),
        key(AppColors.fill, AppColors.border, 'Taken'),
      ],
    );
  }
}

class _NoRoomsState extends StatelessWidget {
  const _NoRoomsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.meeting_room_outlined, color: AppColors.muted),
          SizedBox(width: 12),
          Expanded(child: Text('Room availability has not been added yet.')),
        ],
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.muted, size: 44),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
