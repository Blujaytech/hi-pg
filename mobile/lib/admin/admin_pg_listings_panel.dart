import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../owner/pg/supported_cities.dart';
import '../shared/app_states.dart';
import 'admin_pg_listings_repository.dart';

class AdminPgListingsPanel extends StatefulWidget {
  const AdminPgListingsPanel({super.key});

  @override
  State<AdminPgListingsPanel> createState() => _AdminPgListingsPanelState();
}

class _AdminPgListingsPanelState extends State<AdminPgListingsPanel> {
  final _repository = AdminPgListingsRepository();
  List<AdminPgListing> _listings = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await _repository.list();
      if (mounted) setState(() => _listings = listings);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'PG listings could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<AdminPgListing>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddAdminPgSheet(repository: _repository),
    );
    if (created == null || !mounted) return;
    setState(() => _listings = [created, ..._listings]);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${created.name} is now listed as unverified.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Loading PG listings...');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PG directory',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text('Add discoverable listings and track owner claims.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add PG'),
            ),
          ]),
          const SizedBox(height: 14),
          const AppMessageBanner(
            icon: Icons.privacy_tip_outlined,
            message:
                'Owner mobile is private and is used only to match a Firebase OTP login. Unverified listings cannot expose beds, accept bookings or collect payments.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AppMessageBanner(
              icon: Icons.error_outline,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
          ],
          const SizedBox(height: 14),
          if (_listings.isEmpty)
            const AppEmptyView(
              icon: Icons.add_business_outlined,
              title: 'No admin-created PGs',
              message: 'Use Add PG to create the first natural listing.',
            )
          else
            for (final item in _listings) ...[
              _listingCard(item),
              const SizedBox(height: 11),
            ],
        ],
      ),
    );
  }

  Widget _listingCard(AdminPgListing item) {
    final verified = item.verificationStatus == 'VERIFIED';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(item.name,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            StatusPill(
              label: verified ? 'Verified' : 'Unverified',
              tone: verified ? StatusTone.success : StatusTone.warning,
              icon: verified ? Icons.verified_rounded : Icons.shield_outlined,
            ),
          ]),
          const SizedBox(height: 7),
          Text('${item.address}, ${item.city}',
              style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 24),
          Text('Owner: ${item.ownerName} · ${item.ownerMobile}'),
          const SizedBox(height: 5),
          Text(
            'Claim: ${item.claimStatus.replaceAll('_', ' ').toLowerCase()}  ·  ${item.interestCount} interested',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          if (item.invitationStatus == 'PENDING_PROVIDER') ...[
            const SizedBox(height: 9),
            const Text(
              'Invitation saved. Connect an approved SMS/WhatsApp provider before reporting it as sent.',
              style: TextStyle(color: AppColors.warning, fontSize: 11.5),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AddAdminPgSheet extends StatefulWidget {
  final AdminPgListingsRepository repository;
  const _AddAdminPgSheet({required this.repository});

  @override
  State<_AddAdminPgSheet> createState() => _AddAdminPgSheetState();
}

class _AddAdminPgSheetState extends State<_AddAdminPgSheet> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _description = TextEditingController();
  String? _city;
  String _gender = 'CO_ED';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _owner,
      _mobile,
      _address,
      _state,
      _pincode,
      _latitude,
      _longitude,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await widget.repository.create({
        'name': _name.text.trim(),
        'ownerName': _owner.text.trim(),
        'ownerMobile': _mobile.text.trim(),
        'address': _address.text.trim(),
        'city': _city,
        'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'pincode': _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
        'latitude': double.parse(_latitude.text.trim()),
        'longitude': double.parse(_longitude.text.trim()),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'genderPreference': _gender,
      });
      if (mounted) Navigator.pop(context, created);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'The listing could not be created.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _coordinate(String? value, double min, double max) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < min || parsed > max) {
      return 'Enter a valid coordinate';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add PG listing',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
              'This creates an unverified public listing. Booking stays locked until the matched owner claims it and KYC is approved.',
              style: TextStyle(color: AppColors.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppMessageBanner(
                icon: Icons.error_outline,
                message: _error!,
                color: AppColors.danger,
                background: AppColors.dangerSoft,
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
                controller: _name,
                validator: _required,
                decoration: const InputDecoration(labelText: 'PG name')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _owner,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Owner name')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobile,
              validator: (value) {
                final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                return digits.length < 10 || digits.length > 12
                    ? 'Enter a valid owner mobile number'
                    : null;
              },
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))
              ],
              decoration: const InputDecoration(
                labelText: 'Owner mobile',
                helperText:
                    'Private OTP claim reference; never shown publicly.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _address,
                validator: _required,
                decoration:
                    const InputDecoration(labelText: 'Street / area address')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              items: supportedIndianCities
                  .map((city) =>
                      DropdownMenuItem(value: city, child: Text(city)))
                  .toList(),
              onChanged: (value) => setState(() => _city = value),
              validator: (value) =>
                  value == null ? 'Select a verified city' : null,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _state,
                      decoration: const InputDecoration(labelText: 'State'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pincode'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextFormField(
                controller: _latitude,
                validator: (v) => _coordinate(v, -90, 90),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude'),
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                controller: _longitude,
                validator: (v) => _coordinate(v, -180, 180),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude'),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Men')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Women')),
                DropdownMenuItem(value: 'CO_ED', child: Text('Co-Living')),
              ],
              onChanged: (value) => setState(() => _gender = value!),
              decoration: const InputDecoration(labelText: 'Stay type'),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _description,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving
                  ? 'Creating listing...'
                  : 'Create unverified listing'),
            ),
          ]),
        ),
      ),
    );
  }
}
