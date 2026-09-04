import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';

class PgSearchScreen extends StatefulWidget {
  const PgSearchScreen({super.key});

  @override
  State<PgSearchScreen> createState() => _PgSearchScreenState();
}

class _PgSearchScreenState extends State<PgSearchScreen> {
  final _repository = DiscoveryRepository();
  final _cityController = TextEditingController();
  GenderPreference? _genderPreference;
  late Future<PagedResult<PgSearchResult>> _future;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = _repository.search();
  }

  void _runSearch() {
    setState(() {
      _page = 0;
      _future = _repository.search(
        city: _cityController.text,
        genderPreference: _genderPreference,
        page: 0,
      );
    });
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _future = _repository.search(
        city: _cityController.text,
        genderPreference: _genderPreference,
        page: page,
      );
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a PG')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City', isDense: true),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<GenderPreference?>(
                      value: _genderPreference,
                      hint: const Text('Any'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Any')),
                        ...GenderPreference.values.map((g) => DropdownMenuItem(value: g, child: Text(g.label))),
                      ],
                      onChanged: (value) => setState(() => _genderPreference = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(onPressed: _runSearch, child: const Text('Search')),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<PagedResult<PgSearchResult>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Could not load PG listings right now.';
                  return Center(child: Text(message));
                }
                final result = snapshot.data!;
                if (result.content.isEmpty) {
                  return const Center(child: Text('No PGs match those filters yet.'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: result.content.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final pg = result.content[index];
                          return Card(
                            child: ListTile(
                              onTap: () => context.push('/student/pgs/${pg.id}'),
                              title: Text(pg.name),
                              subtitle: Text('${pg.address}, ${pg.city} • ${pg.genderPreference.label}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    pg.availableBeds > 0 ? '${pg.availableBeds} available' : 'Full',
                                    style: TextStyle(color: pg.availableBeds > 0 ? Colors.green.shade700 : Colors.grey),
                                  ),
                                  if (pg.minRentPerBed != null)
                                    Text('from ₹${pg.minRentPerBed!.toStringAsFixed(0)}/mo'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (result.totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
                            ),
                            Text('Page ${result.page + 1} of ${result.totalPages}'),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _page + 1 < result.totalPages ? () => _goToPage(_page + 1) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
