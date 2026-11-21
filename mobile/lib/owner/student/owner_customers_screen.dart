import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../pg/pg_models.dart';
import '../pg/pg_repository.dart';
import 'student_models.dart';
import 'student_repository.dart';

typedef LoadPropertyStudents = Future<List<Student>> Function(String pgId);

/// Portfolio customer entry point. The backend exposes customers per PG, so
/// this screen composes those existing owner-scoped endpoints and then opens
/// the established property customer workflow for management actions.
class OwnerCustomersScreen extends StatefulWidget {
  final PgDataSource? pgRepository;
  final LoadPropertyStudents? loadStudents;

  const OwnerCustomersScreen({
    super.key,
    this.pgRepository,
    this.loadStudents,
  });

  @override
  State<OwnerCustomersScreen> createState() => _OwnerCustomersScreenState();
}

class _OwnerCustomersScreenState extends State<OwnerCustomersScreen> {
  late final PgDataSource _pgRepository = widget.pgRepository ?? PgRepository();
  late final LoadPropertyStudents _loadStudents =
      widget.loadStudents ?? StudentRepository().listForPg;
  late Future<List<_PropertyCustomers>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_PropertyCustomers>> _load() async {
    final properties = await _pgRepository.list();
    return Future.wait(
      properties.map((pg) async => _PropertyCustomers(
            pg: pg,
            students: await _loadStudents(pg.id),
          )),
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Customers',
        subtitle: 'People, stays and payment status',
      ),
      body: FutureBuilder<List<_PropertyCustomers>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Loading your customers...');
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Your customer portfolio could not be loaded.';
            return AppErrorView(message: message, onRetry: _reload);
          }

          final groups = snapshot.data ?? const <_PropertyCustomers>[];
          if (groups.isEmpty) {
            return AppEmptyView(
              icon: Icons.apartment_outlined,
              title: 'Add a property first',
              message:
                  'Customers are organized by property so beds, fees and payments stay connected correctly.',
              actionLabel: 'Open properties',
              onAction: () => context.go('/owner'),
            );
          }

          final normalizedQuery = _query.trim().toLowerCase();
          final visible = normalizedQuery.isEmpty
              ? groups
              : groups.where((group) {
                  return group.pg.name
                          .toLowerCase()
                          .contains(normalizedQuery) ||
                      group.pg.city.toLowerCase().contains(normalizedQuery) ||
                      group.students.any((student) => student.fullName
                          .toLowerCase()
                          .contains(normalizedQuery));
                }).toList();
          final total =
              groups.fold<int>(0, (sum, group) => sum + group.students.length);
          final active =
              groups.fold<int>(0, (sum, group) => sum + group.active);
          final pending = groups.fold<int>(
              0, (sum, group) => sum + group.pendingPaymentReviews);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _CustomerPortfolioHero(
                  total: total,
                  active: active,
                  pendingReviews: pending,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search property, city or customer',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'By property',
                  trailing:
                      '${groups.length} ${groups.length == 1 ? 'property' : 'properties'}',
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const AppEmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'No matching customers',
                    message: 'Try a customer name, property name or city.',
                  )
                else
                  for (var index = 0; index < visible.length; index++) ...[
                    _PropertyCustomerCard(
                      group: visible[index],
                      onTap: () => context.push(
                        '/owner/pgs/${visible[index].pg.id}/students',
                        extra: visible[index].pg,
                      ),
                    ),
                    if (index != visible.length - 1) const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PropertyCustomers {
  final Pg pg;
  final List<Student> students;

  const _PropertyCustomers({required this.pg, required this.students});

  int get active => students
      .where((student) => student.status != StudentStatus.movedOut)
      .length;

  int get withoutBed => students
      .where((student) =>
          student.status != StudentStatus.movedOut && student.bedLabel == null)
      .length;

  int get pendingPaymentReviews => students
      .where((student) => student.bookingStatus == 'DIRECT_PAYMENT_REVIEW')
      .length;
}

class _CustomerPortfolioHero extends StatelessWidget {
  final int total;
  final int active;
  final int pendingReviews;

  const _CustomerPortfolioHero({
    required this.total,
    required this.active,
    required this.pendingReviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER PORTFOLIO',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$active active ${active == 1 ? 'customer' : 'customers'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$total customer record${total == 1 ? '' : 's'} across your properties',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 12.5,
            ),
          ),
          if (pendingReviews > 0) ...[
            const SizedBox(height: 14),
            StatusPill(
              label:
                  '$pendingReviews direct ${pendingReviews == 1 ? 'payment needs' : 'payments need'} review',
              tone: StatusTone.warning,
              icon: Icons.verified_user_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _PropertyCustomerCard extends StatelessWidget {
  final _PropertyCustomers group;
  final VoidCallback onTap;

  const _PropertyCustomerCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(icon: Icons.apartment_rounded, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.pg.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(group.pg.city,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label:
                        '${group.active} active ${group.active == 1 ? 'customer' : 'customers'}',
                    tone: group.active > 0
                        ? StatusTone.success
                        : StatusTone.neutral,
                  ),
                  if (group.withoutBed > 0)
                    StatusPill(
                      label: '${group.withoutBed} without bed',
                      tone: StatusTone.warning,
                    ),
                  if (group.pendingPaymentReviews > 0)
                    StatusPill(
                      label: '${group.pendingPaymentReviews} payment review',
                      tone: StatusTone.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
