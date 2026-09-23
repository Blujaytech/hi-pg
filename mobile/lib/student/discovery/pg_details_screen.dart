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
import '../booking/booking_repository.dart';
import '../booking/booking_models.dart';
import '../payment/payment_repository.dart';
import '../payment/payment_choice_sheet.dart';
import '../payment/razorpay_checkout.dart';
import '../profile/customer_profile_repository.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';

enum _GuestSignInChoice { google, mobile }

/// PG details with live bed availability. Guests (reached via `/explore`)
/// can see everything; signing in is only asked for when they book a bed,
/// after which booking resumes for the bed they picked.
class PgDetailsScreen extends StatefulWidget {
  final String pgId;

  const PgDetailsScreen({super.key, required this.pgId});

  @override
  State<PgDetailsScreen> createState() => _PgDetailsScreenState();
}

class _PgDetailsScreenState extends State<PgDetailsScreen> {
  final _repository = DiscoveryRepository();
  final _bookingRepository = BookingRepository();
  final _paymentRepository = PaymentRepository();
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

  /// Bed a guest chose before signing in; booked once they are back.
  AvailableBedOption? _pendingBed;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>()..addListener(_resumeAfterSignIn);
    _checkout = RazorpayCheckout(_paymentRepository);
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

    final here = GoRouterState.of(context).matchedLocation;
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
      final here = GoRouterState.of(context).matchedLocation;
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
    final here = GoRouterState.of(context).matchedLocation;
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
    _future = _repository.getDetails(widget.pgId);
  }

  void _reload() => setState(_loadDetails);

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
    var bookingType = bed.bookingMode == 'DAY_WISE'
        ? BookingType.dayWise
        : BookingType.monthly;
    if (bed.bookingMode == 'FLEXIBLE') {
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

    final now = DateTime.now();
    final moveInDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'Choose a move-in date',
    );
    if (moveInDate == null || !mounted) return;

    DateTime? checkOutDate;
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

    final formattedDate = '${moveInDate.day.toString().padLeft(2, '0')}/'
        '${moveInDate.month.toString().padLeft(2, '0')}/${moveInDate.year}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book ${bed.label}?'),
        content: Text('${bookingType.label} booking\nCheck-in: $formattedDate'
            '${checkOutDate == null ? '' : '\nCheckout: ${DateFormat('d MMM yyyy').format(checkOutDate)}'}'
            '\n\nA temporary bed hold will be created. Choose secure online payment or pay the owner directly.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue to payment')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final paymentChoice = await showBookingPaymentChoice(context);
    if (paymentChoice == null || !mounted) return;

    setState(() => _booking = true);
    try {
      final booking = await _bookingRepository.book(
        bedId: bed.id,
        bookingType: bookingType,
        moveInDate: moveInDate,
        checkOutDate: checkOutDate,
      );
      if (!mounted) return;
      if (paymentChoice == BookingPaymentChoice.online) {
        final order = await _paymentRepository.createBookingOrder(booking.id);
        await _checkout.pay(order,
            description: '${bookingType.label} booking at ${booking.pgName}');
      } else {
        setState(() => _booking = false);
        final informed = await context.push<bool>(
            '/student/bookings/${booking.id}/direct-payment?select=true');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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

  Future<void> _openRouteInGoogleMaps(double lat, double lng) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG details'),
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
          final availableBeds = _liveAvailableBeds ?? pg.availableBeds;
          final totalBeds = _liveTotalBeds ?? pg.totalBeds;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                if (pg.latitude != null && pg.longitude != null) ...[
                  const SizedBox(height: 26),
                  _LocationSection(
                    latitude: pg.latitude!,
                    longitude: pg.longitude!,
                    address: '${pg.address}, ${pg.city}',
                    onDirections: () =>
                        _openRouteInGoogleMaps(pg.latitude!, pg.longitude!),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                        child: Text('Rooms & beds',
                            style: Theme.of(context).textTheme.titleLarge)),
                    Text(
                      '${pg.floors.length} floor${pg.floors.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text('Choose a floor, then select an available bed.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                if (pg.floors.isEmpty)
                  const _NoRoomsState()
                else
                  for (var index = 0; index < pg.floors.length; index++) ...[
                    _FloorCard(
                      floor: pg.floors[index],
                      initiallyExpanded: index == 0,
                      booking: _booking,
                      onBookBed: _bookBed,
                    ),
                    if (index != pg.floors.length - 1)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.apartment_rounded,
                      color: AppColors.ink, size: 26),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pg.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_outlined,
                                size: 16, color: AppColors.muted),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${pg.address}, ${pg.city}${pg.state != null ? ', ${pg.state}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            const Divider(height: 1),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _HeaderMetric(
                    icon: Icons.people_alt_outlined,
                    label: 'Property type',
                    value: pg.genderPreference.label,
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.border),
                Expanded(
                  child: _HeaderMetric(
                    icon: Icons.bed_rounded,
                    label: live ? 'Live availability' : 'Availability',
                    value: '$availableBeds of $totalBeds beds',
                    accent:
                        availableBeds > 0 ? AppColors.success : AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 5),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _LocationSection extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;
  final VoidCallback onDirections;

  const _LocationSection({
    required this.latitude,
    required this.longitude,
    required this.address,
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
        CameraPosition(target: _point, zoom: 16.8, tilt: 32, bearing: -8),
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _point,
                  zoom: 16.8,
                  tilt: 32,
                  bearing: -8,
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
                buildingsEnabled: true,
                indoorViewEnabled: true,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Start directions in Google Maps'),
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
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        collapsedShape: const Border(),
        shape: const Border(),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: AppColors.fill, borderRadius: BorderRadius.circular(12)),
          child:
              const Icon(Icons.layers_rounded, color: AppColors.ink, size: 21),
        ),
        title: Text(floor.name, style: Theme.of(context).textTheme.titleMedium),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(15),
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
                    '₹${room.rentPerBed.toStringAsFixed(0)}',
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: available ? AppColors.successSoft : AppColors.fill,
              borderRadius: BorderRadius.circular(9),
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
          if (room.availableBedOptions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Select a bed', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 9) / 2;
                return Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: room.availableBedOptions
                      .map(
                        (bed) => SizedBox(
                          width: itemWidth,
                          child: OutlinedButton.icon(
                            onPressed: booking ? null : () => onBookBed(bed),
                            icon: const Icon(Icons.bed_outlined, size: 18),
                            label: Text(bed.label,
                                overflow: TextOverflow.ellipsis),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 11),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
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
        borderRadius: BorderRadius.circular(18),
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
