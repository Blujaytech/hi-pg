import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../owner/pg/supported_cities.dart';
import '../shared/app_states.dart';
import 'admin_pg_listings_repository.dart';

class AdminPgListingsPanel extends StatefulWidget {
  final AdminPgListingsRepository? repository;

  const AdminPgListingsPanel({super.key, this.repository});

  @override
  State<AdminPgListingsPanel> createState() => _AdminPgListingsPanelState();
}

class _AdminPgListingsPanelState extends State<AdminPgListingsPanel> {
  late final AdminPgListingsRepository _repository;
  final _search = TextEditingController();
  List<AdminPgListing> _listings = const [];
  List<PgImportBatch> _imports = const [];
  String? _cityFilter;
  String? _genderFilter;
  String? _verificationFilter;
  bool _loading = true;
  bool _importing = false;
  final Set<String> _sendingInvitations = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminPgListingsRepository();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Object? listingsError;
      Object? importsError;
      List<AdminPgListing>? listings;
      List<PgImportBatch>? imports;
      try {
        listings = await _repository.list();
      } catch (error) {
        listingsError = error;
      }
      try {
        imports = await _repository.listImports();
      } catch (error) {
        importsError = error;
      }
      if (mounted) {
        setState(() {
          if (listings != null) _listings = listings;
          if (imports != null) _imports = imports;
          if (listingsError != null) {
            _error =
                _message(listingsError, 'PG listings could not be loaded.');
          } else if (importsError != null) {
            _error = _message(
                importsError, 'Previous Excel imports could not be loaded.');
          }
        });
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

  Future<void> _edit(AdminPgListing item) async {
    final updated = await showModalBottomSheet<AdminPgListing>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddAdminPgSheet(
        repository: _repository,
        listing: item,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _listings = _listings
          .map((listing) => listing.id == updated.id ? updated : listing)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} was updated.')),
    );
  }

  Future<void> _delete(AdminPgListing item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this PG listing?'),
        content: Text(
          '${item.name} will be removed from the admin directory and student search. This cannot be undone from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete PG'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.delete(item.id);
      if (!mounted) return;
      setState(() {
        _listings =
            _listings.where((listing) => listing.id != item.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} was deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_message(error, 'The PG could not be deleted.'))),
      );
    }
  }

  Future<void> _callOwner(AdminPgListing item) async {
    final mobile = item.ownerMobile?.trim();
    if (mobile == null || mobile.isEmpty) return;
    final dialNumber = mobile.replaceAll(RegExp(r'[^0-9+]'), '');
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: dialNumber),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The phone dialler could not be opened.')),
      );
    }
  }

  Future<void> _retryInvitation(AdminPgListing item) async {
    if (_sendingInvitations.contains(item.id)) return;
    setState(() => _sendingInvitations.add(item.id));
    try {
      final updated = await _repository.retryInvitation(item.id);
      if (!mounted) return;
      setState(() {
        _listings = [
          for (final listing in _listings)
            if (listing.id == updated.id) updated else listing,
        ];
      });
      final sent = updated.invitationDeliveryStatus == 'SENT';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Owner invitation sent.'
              : updated.invitationFailureReason ??
                  'The SMS provider did not send this invitation.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_message(error, 'The invitation could not be sent.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingInvitations.remove(item.id));
    }
  }

  Future<void> _openLocation(AdminPgListing item) async {
    final locationUrl = item.locationUrl?.trim();
    final uri = locationUrl?.isNotEmpty == true
        ? Uri.tryParse(locationUrl!)
        : item.latitude != null && item.longitude != null
            ? Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': '${item.latitude},${item.longitude}',
              })
            : null;
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The PG location could not be opened.')),
        );
      }
    }
  }

  Future<void> _showPhoto(AdminPgListing item) async {
    final photoUrl = item.photoUrl;
    if (photoUrl == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.name),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: ClipRRect(
            borderRadius: AppRadii.medium,
            child: InteractiveViewer(
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('The imported photo could not be loaded.'),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<AdminPgListing> get _filteredListings {
    final query = _search.text.trim().toLowerCase();
    return _listings.where((item) {
      final searchable = [
        item.name,
        item.address,
        item.city,
        item.ownerName ?? '',
        item.ownerMobile ?? '',
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (_cityFilter == null || item.city == _cityFilter) &&
          (_genderFilter == null || item.genderPreference == _genderFilter) &&
          (_verificationFilter == null ||
              item.verificationStatus == _verificationFilter);
    }).toList();
  }

  bool get _hasActiveFilters =>
      _search.text.isNotEmpty ||
      _cityFilter != null ||
      _genderFilter != null ||
      _verificationFilter != null;

  void _clearFilters() {
    _search.clear();
    setState(() {
      _cityFilter = null;
      _genderFilter = null;
      _verificationFilter = null;
    });
  }

  Future<void> _pickImports() async {
    if (_importing) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || !mounted) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    final uploaded = <PgImportBatch>[];
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw ApiException(
              message: 'The selected Excel file could not be read.');
        }
        uploaded.add(await _repository.uploadImport(file.name, bytes));
      }
      if (!mounted) return;
      setState(() {
        final ids = uploaded.map((batch) => batch.id).toSet();
        _imports = [
          ...uploaded,
          ..._imports.where((batch) => !ids.contains(batch.id))
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${uploaded.length} Excel file(s) staged. Nothing has been published yet.'),
      ));
      if (uploaded.length == 1) await _openImport(uploaded.first);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = _message(error, 'Excel import could not be staged.'));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openImport(PgImportBatch batch) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _ImportBatchSheet(repository: _repository, initial: batch),
    );
    if (changed == true && mounted) await _load();
  }

  String _message(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingView(label: 'Loading PG listings...');
    final filteredListings = _filteredListings;
    final cities = _listings.map((item) => item.city).toSet().toList()..sort();
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
                  Text('Add listings or safely import master Excel sheets.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _importing ? null : _pickImports,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_importing ? 'Reading Excel...' : 'Import Excel'),
              ),
              OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add PG'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const AppMessageBanner(
            icon: Icons.verified_user_outlined,
            message:
                'Excel upload creates a private preview only. Publishing and owner invitations happen only after one explicit batch confirmation. Missing mobile or location does not block a valid listing.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DirectoryMetric(
                  label: 'Total PGs',
                  value: _listings.length,
                  icon: Icons.apartment_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DirectoryMetric(
                  label: 'Unverified',
                  value: _listings
                      .where((item) => item.verificationStatus != 'VERIFIED')
                      .length,
                  icon: Icons.shield_outlined,
                  tone: StatusTone.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DirectoryMetric(
                  label: 'With mobile',
                  value: _listings
                      .where(
                          (item) => item.ownerMobile?.trim().isNotEmpty == true)
                      .length,
                  icon: Icons.phone_outlined,
                  tone: StatusTone.success,
                ),
              ),
            ],
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
          if (_imports.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Excel import batches',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 9),
            for (final batch in _imports.take(10)) ...[
              _importCard(batch),
              const SizedBox(height: 9),
            ],
          ],
          const SizedBox(height: 18),
          Text('Published directory',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search PG, area, owner or mobile',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                Expanded(child: _cityField(cities)),
                Expanded(child: _stayTypeField()),
              ];
              if (constraints.maxWidth >= 520) {
                return Row(children: [
                  fields.first,
                  const SizedBox(width: 10),
                  fields.last,
                ]);
              }
              return Column(children: [
                _cityField(cities),
                const SizedBox(height: 10),
                _stayTypeField(),
              ]);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All status'),
                selected: _verificationFilter == null,
                onSelected: (_) => setState(() => _verificationFilter = null),
              ),
              ChoiceChip(
                label: const Text('Unverified'),
                selected: _verificationFilter == 'UNVERIFIED',
                onSelected: (_) =>
                    setState(() => _verificationFilter = 'UNVERIFIED'),
              ),
              ChoiceChip(
                label: const Text('Verified'),
                selected: _verificationFilter == 'VERIFIED',
                onSelected: (_) =>
                    setState(() => _verificationFilter = 'VERIFIED'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing ${filteredListings.length} of ${_listings.length} PGs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          if (_listings.isEmpty)
            const AppEmptyView(
              icon: Icons.add_business_outlined,
              title: 'No admin-created PGs',
              message: 'Use Add PG or Import Excel to create listings.',
            )
          else if (filteredListings.isEmpty)
            const AppEmptyView(
              icon: Icons.search_off_rounded,
              title: 'No matching PGs',
              message: 'Change the search text or filters and try again.',
            )
          else
            for (final item in filteredListings) ...[
              _listingCard(item),
              const SizedBox(height: 11),
            ],
        ],
      ),
    );
  }

  Widget _cityField(List<String> cities) => DropdownButtonFormField<String>(
        key: ValueKey('city-${_cityFilter ?? 'all'}'),
        initialValue: _cityFilter,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'City'),
        items: [
          const DropdownMenuItem(value: null, child: Text('All cities')),
          ...cities
              .map((city) => DropdownMenuItem(value: city, child: Text(city))),
        ],
        onChanged: (value) => setState(() => _cityFilter = value),
      );

  Widget _stayTypeField() => DropdownButtonFormField<String>(
        key: ValueKey('gender-${_genderFilter ?? 'all'}'),
        initialValue: _genderFilter,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Stay type'),
        items: const [
          DropdownMenuItem(value: null, child: Text('All types')),
          DropdownMenuItem(value: 'MALE', child: Text('Men')),
          DropdownMenuItem(value: 'FEMALE', child: Text('Women')),
          DropdownMenuItem(value: 'CO_ED', child: Text('Co-Living')),
          DropdownMenuItem(value: 'UNSPECIFIED', child: Text('Unspecified')),
        ],
        onChanged: (value) => setState(() => _genderFilter = value),
      );

  Widget _importCard(PgImportBatch batch) {
    final completed = batch.status == 'COMPLETED';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openImport(batch),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.table_view_outlined),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(batch.fileName,
                      style: Theme.of(context).textTheme.titleSmall)),
              StatusPill(
                label: completed ? 'Completed' : 'Preview',
                tone: completed ? StatusTone.success : StatusTone.warning,
                icon: completed
                    ? Icons.check_circle_outline
                    : Icons.preview_outlined,
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              '${batch.publishableRows} publishable · ${batch.validMobileRows} valid mobiles · ${batch.invalidRows} invalid · ${batch.duplicateRows} duplicates',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _listingCard(AdminPgListing item) {
    final verified = item.verificationStatus == 'VERIFIED';
    final owner =
        item.ownerName?.isNotEmpty == true ? item.ownerName! : 'Not provided';
    final mobile =
        item.ownerMobile?.isNotEmpty == true ? item.ownerMobile! : 'No mobile';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(item.name,
                    style: Theme.of(context).textTheme.titleMedium)),
            StatusPill(
              label: verified ? 'Verified' : 'Unverified',
              tone: verified ? StatusTone.success : StatusTone.warning,
              icon: verified ? Icons.verified_rounded : Icons.shield_outlined,
            ),
          ]),
          const SizedBox(height: 7),
          Text('${item.address}, ${item.city}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(
                label: item.photoUrl == null ? 'No real photo' : 'Photo ready',
                tone: item.photoUrl == null
                    ? StatusTone.neutral
                    : StatusTone.success,
                icon: item.photoUrl == null
                    ? Icons.image_not_supported_outlined
                    : Icons.image_outlined,
              ),
              StatusPill(
                label: item.locationUrl != null ||
                        (item.latitude != null && item.longitude != null)
                    ? 'Location ready'
                    : 'No location',
                tone: item.locationUrl != null ||
                        (item.latitude != null && item.longitude != null)
                    ? StatusTone.success
                    : StatusTone.neutral,
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
          const Divider(height: 24),
          Text('Owner: $owner · $mobile'),
          const SizedBox(height: 5),
          Text(
            'Claim: ${item.claimStatus.replaceAll('_', ' ').toLowerCase()} · ${item.interestCount} interested',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          if (item.invitationDeliveryStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              item.invitationDeliveryStatus == 'SENT'
                  ? 'Invitation SMS accepted by the provider.'
                  : 'Invitation: ${item.invitationFailureReason ?? item.invitationDeliveryStatus!.toLowerCase()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.invitationDeliveryStatus == 'SENT'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.photoUrl != null)
                OutlinedButton.icon(
                  onPressed: () => _showPhoto(item),
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('View photo'),
                ),
              if (item.locationUrl != null ||
                  (item.latitude != null && item.longitude != null))
                OutlinedButton.icon(
                  onPressed: () => _openLocation(item),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open map'),
                ),
              if (item.ownerMobile?.trim().isNotEmpty == true)
                OutlinedButton.icon(
                  onPressed: () => _callOwner(item),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call'),
                ),
              if (item.ownerMobile?.trim().isNotEmpty == true &&
                  item.invitationStatus != 'CLAIMED')
                OutlinedButton.icon(
                  onPressed: _sendingInvitations.contains(item.id)
                      ? null
                      : () => _retryInvitation(item),
                  icon: _sendingInvitations.contains(item.id)
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sms_outlined, size: 18),
                  label: Text(item.invitationDeliveryStatus == 'SENT'
                      ? 'SMS sent'
                      : 'Retry SMS'),
                ),
              OutlinedButton.icon(
                onPressed: () => _edit(item),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _delete(item),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _DirectoryMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final StatusTone tone;

  const _DirectoryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (tone) {
      StatusTone.success => (AppColors.success, AppColors.successSoft),
      StatusTone.warning => (AppColors.warning, AppColors.warningSoft),
      StatusTone.danger => (AppColors.danger, AppColors.dangerSoft),
      _ => (AppColors.ink, AppColors.fill),
    };
    return AppSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: background == AppColors.fill ? AppColors.muted : color,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImportBatchSheet extends StatefulWidget {
  final AdminPgListingsRepository repository;
  final PgImportBatch initial;

  const _ImportBatchSheet({required this.repository, required this.initial});

  @override
  State<_ImportBatchSheet> createState() => _ImportBatchSheetState();
}

class _ImportBatchSheetState extends State<_ImportBatchSheet> {
  late PgImportBatch _batch = widget.initial;
  bool _loading = true;
  bool _publishing = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final batch = await widget.repository.getImport(_batch.id);
      if (mounted) setState(() => _batch = batch);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Import preview could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish this Excel batch?'),
        content: Text(
          '${_batch.publishableRows} valid PGs will be published as unverified listings. Invitations will be attempted only for ${_batch.validMobileRows} rows with valid mobile numbers. Invalid and duplicate rows will be skipped.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish & invite all valid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final batch = await widget.repository.publishImport(_batch.id);
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${batch.publishedRows} PGs published; ${batch.invitedRows} invitations sent.'),
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'The batch could not be published.');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _editLocation(PgImportRow row) async {
    final latitude =
        TextEditingController(text: row.latitude?.toString() ?? '');
    final longitude =
        TextEditingController(text: row.longitude?.toString() ?? '');
    final url = TextEditingController(text: row.locationUrl ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location · row ${row.sourceRowNumber}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Google Maps URL (optional)')),
            const SizedBox(height: 10),
            TextField(
                controller: latitude,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration:
                    const InputDecoration(labelText: 'Latitude (optional)')),
            const SizedBox(height: 10),
            TextField(
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration:
                    const InputDecoration(labelText: 'Longitude (optional)')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    try {
      final batch = await widget.repository.updateImportLocation(
        _batch.id,
        row.id,
        latitude: latitude.text.trim().isEmpty
            ? null
            : double.tryParse(latitude.text.trim()),
        longitude: longitude.text.trim().isEmpty
            ? null
            : double.tryParse(longitude.text.trim()),
        locationUrl: url.text.trim().isEmpty ? null : url.text.trim(),
      );
      if (mounted) setState(() => _batch = batch);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Location could not be saved.');
      }
    } finally {
      latitude.dispose();
      longitude.dispose();
      url.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 320,
          child: AppLoadingView(label: 'Reading import preview...'));
    }
    final completed = _batch.status == 'COMPLETED';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_batch.fileName,
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        onPressed: () => Navigator.pop(context, _changed),
                        icon: const Icon(Icons.close)),
                  ]),
                  Text('Sheet: ${_batch.sourceSheet}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Text(
                      '${_batch.totalRows} rows · ${_batch.publishableRows} publishable · ${_batch.validMobileRows} invitations eligible'),
                  Text(
                      '${_batch.invalidRows} invalid · ${_batch.duplicateRows} duplicates · ${_batch.warningRows} warnings',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    AppMessageBanner(
                        icon: Icons.error_outline,
                        message: _error!,
                        color: AppColors.danger,
                        background: AppColors.dangerSoft),
                  ],
                  const SizedBox(height: 12),
                  if (!completed)
                    FilledButton.icon(
                      onPressed: _publishing ? null : _publish,
                      icon: const Icon(Icons.publish_outlined),
                      label: Text(_publishing
                          ? 'Publishing...'
                          : 'Publish & invite all valid PGs'),
                    )
                  else
                    AppMessageBanner(
                      icon: Icons.check_circle_outline,
                      message:
                          '${_batch.publishedRows} PGs published and ${_batch.invitedRows} invitations sent.',
                    ),
                ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _batch.rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _batch.rows[index];
                final blocked = row.validationStatus == 'INVALID' ||
                    row.validationStatus == 'DUPLICATE';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    'Row ${row.sourceRowNumber} · ${row.name ?? 'Missing name'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall)),
                            Icon(
                                blocked
                                    ? Icons.block_outlined
                                    : Icons.check_circle_outline,
                                color: blocked
                                    ? AppColors.danger
                                    : AppColors.success,
                                size: 19),
                          ]),
                          const SizedBox(height: 5),
                          Text(
                              '${row.address ?? 'Missing address'}, ${row.city ?? 'Missing city'}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (row.imageCount > 0) ...[
                            const SizedBox(height: 5),
                            Text(
                                '${row.imageCount} embedded image${row.imageCount == 1 ? '' : 's'} ready',
                                style: const TextStyle(
                                    color: AppColors.success, fontSize: 11.5)),
                          ],
                          if (row.validationMessages.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(row.validationMessages.join(' · '),
                                style: const TextStyle(
                                    color: AppColors.warning, fontSize: 11.5)),
                          ],
                          if (!completed) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _editLocation(row),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(row.locationUrl == null &&
                                      row.latitude == null
                                  ? 'Add location'
                                  : 'Edit location'),
                            ),
                          ],
                        ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddAdminPgSheet extends StatefulWidget {
  final AdminPgListingsRepository repository;
  final AdminPgListing? listing;

  const _AddAdminPgSheet({
    required this.repository,
    this.listing,
  });

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
  final _locationUrl = TextEditingController();
  final _description = TextEditingController();
  String? _city;
  String _gender = 'CO_ED';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    if (listing == null) return;
    _name.text = listing.name;
    _owner.text = listing.ownerName ?? '';
    _mobile.text = listing.ownerMobile ?? '';
    _address.text = listing.address;
    _state.text = listing.state ?? '';
    _pincode.text = listing.pincode ?? '';
    _latitude.text = listing.latitude?.toString() ?? '';
    _longitude.text = listing.longitude?.toString() ?? '';
    _locationUrl.text = listing.locationUrl ?? '';
    _description.text = listing.description ?? '';
    _city = listing.city;
    _gender = listing.genderPreference;
  }

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
      _locationUrl,
      _description
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
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'ownerName': _optional(_owner.text),
        'ownerMobile': _optional(_mobile.text),
        'address': _address.text.trim(),
        'city': _city,
        'state': _optional(_state.text),
        'pincode': _optional(_pincode.text),
        'latitude': _number(_latitude.text),
        'longitude': _number(_longitude.text),
        'locationUrl': _optional(_locationUrl.text),
        'description': _optional(_description.text),
        'genderPreference': _gender,
      };
      final saved = widget.listing == null
          ? await widget.repository.create(data)
          : await widget.repository.update(widget.listing!.id, data);
      if (mounted) Navigator.pop(context, saved);
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

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
  double? _number(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value.trim());
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _mobileValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length < 10 || digits.length > 12
        ? 'Enter a valid owner mobile number'
        : null;
  }

  String? _coordinates(String? _) {
    final latitude = _number(_latitude.text);
    final longitude = _number(_longitude.text);
    if (_latitude.text.trim().isEmpty && _longitude.text.trim().isEmpty) {
      return null;
    }
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return 'Provide both valid coordinates or leave both empty';
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
            Text(widget.listing == null ? 'Add PG listing' : 'Edit PG listing',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
                'Owner mobile, coordinates and Google Maps URL are optional. A mobile is required only to send an owner invitation.',
                style: TextStyle(color: AppColors.muted)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppMessageBanner(
                  icon: Icons.error_outline,
                  message: _error!,
                  color: AppColors.danger,
                  background: AppColors.dangerSoft),
            ],
            const SizedBox(height: 18),
            TextFormField(
                controller: _name,
                validator: _required,
                decoration: const InputDecoration(labelText: 'PG name')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _owner,
                decoration:
                    const InputDecoration(labelText: 'Owner name (optional)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobile,
              validator: _mobileValidator,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Owner mobile (optional)',
                  helperText: 'Private claim reference; never shown publicly.'),
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
            TextFormField(
                controller: _locationUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Google Maps URL (optional)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _latitude,
                      validator: _coordinates,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration:
                          const InputDecoration(labelText: 'Latitude'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                      controller: _longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration:
                          const InputDecoration(labelText: 'Longitude'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Men')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Women')),
                DropdownMenuItem(value: 'CO_ED', child: Text('Co-Living')),
                DropdownMenuItem(
                    value: 'UNSPECIFIED', child: Text('Unspecified')),
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
                    ? 'Saving listing...'
                    : widget.listing == null
                        ? 'Create unverified listing'
                        : 'Save changes')),
          ]),
        ),
      ),
    );
  }
}
