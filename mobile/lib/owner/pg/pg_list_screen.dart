import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_state.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../../shared/brand/hi_pg_brand.dart';
import 'pg_models.dart';
import 'pg_repository.dart';

/// Owner home tab: greeting, portfolio at a glance and every property with
/// one-tap shortcuts into its rooms, students and expenses.
class PgListScreen extends StatefulWidget {
  final PgDataSource? repository;

  const PgListScreen({super.key, this.repository});

  @override
  State<PgListScreen> createState() => _PgListScreenState();
}

class _PgListScreenState extends State<PgListScreen>
    with WidgetsBindingObserver {
  late final PgDataSource _repository;
  List<Pg> _pgs = const [];
  bool _loading = true;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PgRepository();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(showSpinner: false);
  }

  Future<void> _load({bool showSpinner = true}) async {
    final requestId = ++_requestGeneration;
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final pgs = await _repository.list();
      if (!mounted || requestId != _requestGeneration) return;
      setState(() {
        _pgs = pgs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestGeneration) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Your properties could not be loaded.';
      });
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showFormSheet<Pg>(
      context,
      (_) => _PgFormSheet(repository: _repository),
    );
    if (created == null || !mounted) return;

    // The POST response is the source of truth. Show it immediately instead
    // of waiting for a second GET, then reconcile quietly with the server.
    ++_requestGeneration;
    setState(() {
      _pgs = [created, ..._pgs.where((pg) => pg.id != created.id)];
      _loading = false;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.name} is ready to set up.')),
    );
    await _reconcileAfterCreate(created);
  }

  Future<void> _reconcileAfterCreate(Pg created) async {
    final requestId = ++_requestGeneration;
    try {
      final serverPgs = await _repository.list();
      if (!mounted || requestId != _requestGeneration) return;
      final containsCreated = serverPgs.any((pg) => pg.id == created.id);
      setState(() {
        _pgs = containsCreated
            ? serverPgs
            : [created, ...serverPgs.where((pg) => pg.id != created.id)];
      });
    } catch (_) {
      // Creation already succeeded and its response is rendered. A later
      // pull-to-refresh can retry this non-essential reconciliation.
    }
  }

  Future<void> _openEditSheet(Pg pg) async {
    final updated = await showFormSheet<Pg>(
      context,
      (_) => _PgFormSheet(repository: _repository, initial: pg),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _pgs =
          _pgs.map((item) => item.id == updated.id ? updated : item).toList();
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} was updated.')),
    );
  }

  void _open(Pg pg, String section) {
    context.push('/owner/pgs/${pg.id}/$section', extra: pg);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (context.watch<AuthState>().fullName ?? '').trim();
    final firstName =
        fullName.isEmpty ? 'there' : fullName.split(RegExp(r'\s+')).first;
    return Scaffold(
      appBar: AppBar(
        title: const HiPgLockup(height: 26),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _AvatarButton(
              initial: fullName.isEmpty ? null : fullName.characters.first,
              onTap: () => context.go('/owner/account'),
            ),
          ),
        ],
      ),
      floatingActionButton: !_loading && _error == null && _pgs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add property'),
            )
          : null,
      body: _buildBody(firstName),
    );
  }

  Widget _buildBody(String firstName) {
    if (_loading) {
      return const AppLoadingView(label: 'Loading your properties...');
    }
    if (_error != null && _pgs.isEmpty) {
      return AppErrorView(message: _error!, onRetry: _load);
    }
    if (_pgs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: AppEmptyView(
                  icon: Icons.add_home_work_outlined,
                  title: 'Add your first property',
                  message:
                      'Create your PG, then add floors, rooms and beds in a simple guided flow.',
                  actionLabel: 'Add property',
                  actionIcon: Icons.add_rounded,
                  onAction: _openCreateSheet,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeCount = _pgs.where((pg) => pg.status == PgStatus.active).length;
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 104),
        children: [
          Text(
            '${_greeting()}, $firstName',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text('Your properties',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          _PortfolioSummary(total: _pgs.length, active: activeCount),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'All properties',
            trailing:
                '${_pgs.length} ${_pgs.length == 1 ? 'property' : 'properties'}',
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            const AppMessageBanner(
              icon: Icons.sync_problem_rounded,
              message: 'Showing saved properties. Pull down to sync again.',
              color: AppColors.warning,
              background: AppColors.warningSoft,
            ),
            const SizedBox(height: 12),
          ],
          for (var index = 0; index < _pgs.length; index++) ...[
            _PropertyCard(
              pg: _pgs[index],
              onOpen: (section) => _open(_pgs[index], section),
              onEdit: () => _openEditSheet(_pgs[index]),
            ),
            if (index != _pgs.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AvatarButton extends StatelessWidget {
  final String? initial;
  final VoidCallback onTap;

  const _AvatarButton({required this.initial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Account',
      child: Material(
        color: AppColors.ink,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: initial == null
                  ? const Icon(Icons.person_rounded,
                      color: Colors.white, size: 20)
                  : Text(
                      initial!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioSummary extends StatelessWidget {
  final int total;
  final int active;

  const _PortfolioSummary({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final paused = total - active;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$active active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paused > 0 ? '$paused paused' : 'All live',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : active / total,
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: .14),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Pg pg;
  final ValueChanged<String> onOpen;
  final VoidCallback onEdit;

  const _PropertyCard({
    required this.pg,
    required this.onOpen,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final active = pg.status == PgStatus.active;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => onOpen('floors'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(
                      icon: Icons.apartment_rounded, size: 50, dark: true),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pg.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${pg.address}, ${pg.city}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusPill(
                              label: active ? 'Active' : 'Inactive',
                              tone: active
                                  ? StatusTone.success
                                  : StatusTone.neutral,
                              dot: true,
                            ),
                            StatusPill(
                              label: pg.genderPreference.label,
                              icon: Icons.people_alt_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    tooltip: 'Edit property',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.subtle, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              children: [
                _CardAction(
                  icon: Icons.layers_outlined,
                  label: 'Rooms',
                  onTap: () => onOpen('floors'),
                ),
                const VerticalDivider(width: 1),
                _CardAction(
                  icon: Icons.group_outlined,
                  label: 'Customers',
                  onTap: () => onOpen('students'),
                ),
                const VerticalDivider(width: 1),
                _CardAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'Expenses',
                  onTap: () => onOpen('expenses'),
                ),
                const VerticalDivider(width: 1),
                _CardAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Payments',
                  onTap: () => onOpen('direct-payment-settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.ink),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PgFormSheet extends StatefulWidget {
  final PgDataSource repository;
  final Pg? initial;

  const _PgFormSheet({required this.repository, this.initial});

  @override
  State<_PgFormSheet> createState() => _PgFormSheetState();
}

class _PgFormSheetState extends State<_PgFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  LatLng? _location;
  GenderPreference _gender = GenderPreference.coEd;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _gender = initial?.genderPreference ?? GenderPreference.coEd;
    if (initial?.latitude != null && initial?.longitude != null) {
      _location = LatLng(initial!.latitude!, initial.longitude!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Pg saved;
      final initial = widget.initial;
      if (initial == null) {
        saved = await widget.repository.create(
          name: _name.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          genderPreference: _gender,
        );
      } else {
        saved = await widget.repository.update(Pg(
          id: initial.id,
          name: _name.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          state: initial.state,
          pincode: initial.pincode,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          description: initial.description,
          genderPreference: _gender,
          status: initial.status,
        ));
      }
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PropertyLocationPicker(
          initial: _location,
          city: _city.text.trim(),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _location = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        icon: _isEditing
            ? Icons.edit_location_alt_rounded
            : Icons.add_home_work_rounded,
        title: _isEditing ? 'Edit property' : 'Add a property',
        subtitle: _isEditing
            ? 'Keep property and map details accurate'
            : 'Start with the essential details',
        children: [
          if (_error != null) ...[
            AppMessageBanner(
              icon: Icons.error_outline_rounded,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Property name',
              hintText: 'e.g. Sunrise Men’s PG',
              prefixIcon: Icon(Icons.apartment_rounded),
            ),
            validator: _required,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _address,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Street address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: _required,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _city,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'City',
              prefixIcon: Icon(Icons.location_city_rounded),
            ),
            validator: _required,
          ),
          const SizedBox(height: 14),
          _PropertyLocationField(
            location: _location,
            enabled: !_saving,
            onTap: _pickLocation,
            onClear: _location == null
                ? null
                : () => setState(() => _location = null),
          ),
          const SizedBox(height: 18),
          Text('Who is it for?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<GenderPreference>(
            segments: GenderPreference.values
                .map((gender) => ButtonSegment(
                      value: gender,
                      label: Text(gender.label),
                    ))
                .toList(),
            selected: {_gender},
            onSelectionChanged: _saving
                ? null
                : (values) => setState(() => _gender = values.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(_isEditing ? 'Save changes' : 'Create property'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
}

class _PropertyLocationField extends StatelessWidget {
  final LatLng? location;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PropertyLocationField({
    required this.location,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = location != null;
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.successSoft : AppColors.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppColors.success.withValues(alpha: .28)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
        leading: IconTile(
          icon: selected
              ? Icons.location_on_rounded
              : Icons.add_location_alt_outlined,
          size: 42,
        ),
        title: Text(selected ? 'Property location set' : 'Set property on map'),
        subtitle: Text(
          selected
              ? '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}'
              : 'Recommended - needed for the customer map and directions',
        ),
        trailing: selected
            ? IconButton(
                onPressed: enabled ? onClear : null,
                tooltip: 'Remove map location',
                icon: const Icon(Icons.close_rounded),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _PropertyLocationPicker extends StatefulWidget {
  final LatLng? initial;
  final String city;

  const _PropertyLocationPicker({required this.initial, required this.city});

  @override
  State<_PropertyLocationPicker> createState() =>
      _PropertyLocationPickerState();
}

class _PropertyLocationPickerState extends State<_PropertyLocationPicker> {
  LatLng? _selected;

  late final LatLng _start = widget.initial ?? _cityCenter(widget.city);

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin property location'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text('Save'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _start, zoom: 14.5),
            mapType: MapType.normal,
            buildingsEnabled: true,
            indoorViewEnabled: true,
            compassEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (point) => setState(() => _selected = point),
            markers: _selected == null
                ? const <Marker>{}
                : {
                    Marker(
                      markerId: const MarkerId('property-location'),
                      position: _selected!,
                      infoWindow: const InfoWindow(title: 'Property location'),
                    ),
                  },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Move the map and tap the exact property location.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Use this location'),
        ),
      ),
    );
  }

  static LatLng _cityCenter(String city) {
    final normalized = city.trim().toLowerCase();
    const centers = <String, LatLng>{
      'hyderabad': LatLng(17.3850, 78.4867),
      'secunderabad': LatLng(17.4399, 78.4983),
      'bengaluru': LatLng(12.9716, 77.5946),
      'bangalore': LatLng(12.9716, 77.5946),
      'chennai': LatLng(13.0827, 80.2707),
      'mumbai': LatLng(19.0760, 72.8777),
      'pune': LatLng(18.5204, 73.8567),
      'delhi': LatLng(28.6139, 77.2090),
      'kolkata': LatLng(22.5726, 88.3639),
    };
    return centers[normalized] ?? const LatLng(17.3850, 78.4867);
  }
}
