import 'dart:async';
import 'package:flutter/material.dart';
import '../application/location_tracker.dart';
import '../domain/external_navigation.dart';
import '../domain/fare.dart';
import '../domain/ride_repository.dart';
import '../domain/route_planner.dart';
import 'driver_screen.dart';
import 'passenger_screen.dart';
import 'ride_theme.dart';
import 'ride_widgets.dart';
import 'welcome_map_hero.dart';

class RideMoveApp extends StatelessWidget {
  final RideRepository repository;
  final LocationTracker? tracker;
  final ExternalNavigation? navigation;
  final RoutePlanner? routePlanner;
  final String? startupError;
  const RideMoveApp({
    super.key,
    required this.repository,
    this.startupError,
    this.tracker,
    this.navigation,
    this.routePlanner,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RideMove',
    debugShowCheckedModeBanner: false,
    theme: rideTheme(),
    home: startupError == null
        ? RideShell(
            repository: repository,
            tracker: tracker,
            navigation: navigation,
            routePlanner: routePlanner,
          )
        : Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(startupError!),
              ),
            ),
          ),
  );
}

class RideShell extends StatefulWidget {
  final RideRepository repository;
  final LocationTracker? tracker;
  final ExternalNavigation? navigation;
  final RoutePlanner? routePlanner;
  const RideShell({
    super.key,
    required this.repository,
    this.tracker,
    this.navigation,
    this.routePlanner,
  });
  @override
  State<RideShell> createState() => _RideShellState();
}

class _RideShellState extends State<RideShell> with WidgetsBindingObserver {
  RideRepository get repo => widget.repository;
  JsonRow? me;
  List<JsonRow> trips = [],
      users = [],
      vehicles = [],
      locations = [],
      payments = [];
  bool busy = false, registering = false, loading = false;
  String? loadError;
  int tab = 0, ticks = 0;
  String registerRole = 'passenger';
  Timer? timer;
  int sessionEpoch = 0;
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      document = TextEditingController();

  bool get liveTrip =>
      trips.any((t) => t.isActiveTrip) ||
      (role == 'driver' && me?['available'] == true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (repo.signedIn) refresh();
    // Viaje activo o conductor conectado: cada 3 s. En reposo: cada 15 s.
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      ticks++;
      if (me != null && !busy && (liveTrip || ticks % 5 == 0)) {
        refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tracker?.stop();
    timer?.cancel();
    for (final c in [email, password, name, document]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.tracker?.stop();
    } else if (state == AppLifecycleState.resumed && me != null) {
      refresh(silent: true);
    }
  }

  bool get onMap =>
      me != null && me!['active'] == true && role != 'admin' && tab == 0;

  /// En el mapa los avisos aparecen arriba para no tapar los botones del panel.
  void message(String text) {
    if (!mounted) return;
    final height = MediaQuery.sizeOf(context).height;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 3),
          margin: onMap
              ? EdgeInsets.fromLTRB(12, 0, 12, (height - 240).clamp(12, 2000))
              : null,
        ),
      );
  }

  Future<void> refresh({bool silent = false}) async {
    if (loading) return;
    loading = true;
    final epoch = sessionEpoch;
    if (!silent && mounted) setState(() {});
    try {
      final profile = await repo.profile();
      if (profile['active'] != true) {
        await widget.tracker?.stop();
        if (mounted && epoch == sessionEpoch) {
          setState(() {
            me = profile;
            trips = users = vehicles = locations = payments = [];
            loadError = null;
          });
        }
        return;
      }
      final data = await Future.wait([
        repo.trips(),
        repo.users(),
        repo.vehicles(),
        repo.locations(),
        profile['role'] == 'passenger'
            ? repo.payments()
            : Future.value(<JsonRow>[]),
      ]);
      if (mounted && epoch == sessionEpoch && repo.signedIn) {
        setState(() {
          me = profile;
          trips = data[0];
          users = data[1];
          vehicles = data[2];
          locations = data[3];
          payments = data[4];
          loadError = null;
        });
        final driving = data[0].any(
          (t) =>
              t['driver_id'] == profile['id'] &&
              assignedStatuses.contains(t['status']),
        );
        if (profile['role'] == 'driver' &&
            profile['available'] != true &&
            !driving) {
          await widget.tracker?.stop();
        }
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          loadError = 'No pudimos actualizar los datos. Revisa tu conexión.';
        });
      }
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  /// Ejecuta una acción, refresca y muestra el resultado. Devuelve si tuvo éxito.
  Future<bool> act(Future<void> Function() action, {String? success}) async {
    if (busy) return false;
    setState(() => busy = true);
    var ok = false;
    try {
      await action();
      ok = true;
      if (repo.signedIn) {
        busy = false;
        await refresh(silent: true);
      }
      if (success != null) message(success);
    } on AppFailure catch (e) {
      message(e.message);
    } catch (e) {
      message(
        e is StateError
            ? e.message
            : 'No se pudo completar la acción. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return ok;
  }

  Future<void> command(String name, JsonRow params, {String? success}) =>
      act(() => repo.command(name, params), success: success);
  String get role => me?['role'] ?? 'passenger';
  String person(dynamic id) =>
      users
          .where((u) => u['id'] == id)
          .map((u) => '${u['name']}')
          .firstOrNull ??
      'Por asignar';

  Widget heading(String text, [String? sub]) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.headlineSmall),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: muted, height: 1.5)),
        ],
      ],
    ),
  );
  Widget panel(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EAF5)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: secret,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
      ),
    ),
  );
  Widget button(
    String text,
    VoidCallback action, {
    IconData icon = Icons.arrow_forward_rounded,
  }) => FilledButton.icon(
    onPressed: busy ? null : action,
    icon: Icon(icon, size: 19),
    label: Text(text),
  );

  @override
  Widget build(BuildContext context) {
    final logged = me != null;
    final mapHome =
        logged && me!['active'] == true && role != 'admin' && tab == 0;
    return Scaffold(
      appBar: mapHome
          ? null
          : AppBar(
              title: const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RideBrand(),
              ),
              toolbarHeight: 70,
              actions: [
                if (repo.demo)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Chip(
                      label: Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: mist,
                    ),
                  ),
              ],
            ),
      body: Column(
        children: [
          if (!mapHome && (busy || loading))
            const LinearProgressIndicator(minHeight: 2),
          if (loadError != null)
            SafeArea(
              bottom: false,
              child: MaterialBanner(
                content: Text(loadError!),
                actions: [
                  TextButton(
                    onPressed: () => refresh(),
                    child: const Text('Reintentar'),
                  ),
                  if (!logged)
                    TextButton(
                      onPressed: () async {
                        await repo.signOut();
                        setState(() => loadError = null);
                      },
                      child: const Text('Volver'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: mapHome
                ? (role == 'driver' ? driverHome() : passengerHome())
                : SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                            children: !logged
                                ? auth()
                                : me!['active'] != true
                                ? [
                                    heading(
                                      'Cuenta suspendida',
                                      'Contacta con la administración para revisar tu cuenta.',
                                    ),
                                    button('Cerrar sesión', logout),
                                  ]
                                : tab == 2
                                ? profile()
                                : tab == 1
                                ? history()
                                : adminHome(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: logged
          ? NavigationBar(
              height: 64,
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    role == 'admin'
                        ? Icons.space_dashboard_outlined
                        : role == 'driver'
                        ? Icons.directions_car_outlined
                        : Icons.near_me_outlined,
                  ),
                  selectedIcon: Icon(
                    role == 'admin'
                        ? Icons.space_dashboard_rounded
                        : role == 'driver'
                        ? Icons.directions_car_rounded
                        : Icons.near_me_rounded,
                  ),
                  label: role == 'admin'
                      ? 'Panel'
                      : role == 'driver'
                      ? 'Conducir'
                      : 'Viajar',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Viajes',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Cuenta',
                ),
              ],
            )
          : null,
    );
  }

  Widget passengerHome() => PassengerScreen(
    repository: repo,
    planner: widget.routePlanner,
    device: widget.tracker?.device,
    navigation: widget.navigation,
    me: me!,
    trips: trips,
    users: users,
    vehicles: vehicles,
    locations: locations,
    payments: payments,
    busy: busy,
    run: act,
    notify: message,
  );

  Widget driverHome() => DriverScreen(
    repository: repo,
    planner: widget.routePlanner,
    tracker: widget.tracker,
    navigation: widget.navigation,
    me: me!,
    trips: trips,
    users: users,
    vehicles: vehicles,
    locations: locations,
    busy: busy,
    run: act,
    notify: message,
    onEditVehicle: editVehicle,
  );

  String cedula() => document.text.replaceAll(RegExp(r'[^0-9]'), '');

  List<Widget> auth() => [
    const WelcomeMapHero(),
    heading(
      repo.demo
          ? 'Explora RideMove'
          : registering
          ? 'Crea tu cuenta'
          : 'Qué bueno verte',
      repo.demo
          ? 'Prueba el viaje completo: pide un servicio y mira cómo el conductor llega, te recoge y te lleva.'
          : registering
          ? 'Regístrate con tu cédula en menos de un minuto.'
          : 'Tu próximo destino empieza aquí.',
    ),
    if (repo.demo)
      ...roleLabels.entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.centerLeft,
            ),
            onPressed: busy ? null : () => act(() => repo.signIn(e.key, '')),
            icon: Icon(
              e.key == 'driver'
                  ? Icons.directions_car_outlined
                  : e.key == 'admin'
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
            ),
            label: Text('Entrar como ${e.value.toLowerCase()}'),
          ),
        ),
      )
    else ...[
      if (registering) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'passenger',
                label: Text('Quiero viajar'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'driver',
                label: Text('Quiero conducir'),
                icon: Icon(Icons.directions_car_outlined),
              ),
            ],
            selected: {registerRole},
            onSelectionChanged: (s) => setState(() => registerRole = s.first),
          ),
        ),
        field(name, 'Nombre completo', icon: Icons.badge_outlined),
        field(
          document,
          registerRole == 'passenger'
              ? 'Número de cédula'
              : 'Número de cédula (opcional)',
          keyboard: TextInputType.number,
          icon: Icons.credit_card_outlined,
        ),
      ],
      field(
        email,
        'Correo electrónico',
        keyboard: TextInputType.emailAddress,
        icon: Icons.mail_outline,
      ),
      field(password, 'Contraseña', secret: true, icon: Icons.lock_outline),
      button(registering ? 'Crear cuenta' : 'Iniciar sesión', () {
        if (!RegExp(
              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
            ).hasMatch(email.text.trim()) ||
            password.text.length < 8 ||
            (registering && name.text.trim().length < 2) ||
            (registering && registerRole == 'passenger' && cedula().isEmpty) ||
            (registering &&
                cedula().isNotEmpty &&
                !RegExp(r'^\d{5,10}$').hasMatch(cedula()))) {
          message(
            'Escribe un correo válido, una contraseña de al menos 8 caracteres, tu nombre y, si vas a viajar, tu cédula (5 a 10 dígitos).',
          );
          return;
        }
        act(() async {
          if (registering) {
            final ready = await repo.signUp(
              email.text.trim(),
              password.text,
              name.text.trim(),
              registerRole,
              document: cedula(),
            );
            if (!ready) {
              message(
                'Revisa tu correo para confirmar la cuenta y luego inicia sesión.',
              );
              setState(() => registering = false);
            }
          } else {
            await repo.signIn(email.text.trim(), password.text);
          }
        });
      }),
      TextButton(
        onPressed: () => setState(() => registering = !registering),
        child: Text(
          registering ? 'Ya tengo una cuenta' : 'Soy nuevo, crear cuenta',
        ),
      ),
    ],
  ];

  List<Widget> adminHome() {
    final done = trips.where((t) => t.tripStatus == 'completed');
    final revenue = done.fold(0, (s, t) => s + (t.fareCents ?? 0));
    return [
      heading(
        'Hola, ${'${me!['name']}'.split(' ').first} 👋',
        'Así se mueve nuestra comunidad.',
      ),
      panel(
        Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 16,
          children: [
            metric('${users.length}', 'Usuarios'),
            metric('${trips.where((t) => t.isActiveTrip).length}', 'Activos'),
            metric('${done.length}', 'Finalizados'),
            metric(formatCop(revenue), 'Facturado'),
          ],
        ),
        color: mist,
      ),
      heading('Viajes en curso'),
      if (!trips.any((t) => t.isActiveTrip))
        panel(const Text('No hay viajes en curso ahora.')),
      ...trips
          .where((t) => t.isActiveTrip)
          .map(
            (t) => TripHistoryCard(
              trip: t,
              counterpart:
                  '${person(t['passenger_id'])} → ${t['driver_id'] == null ? 'sin conductor' : person(t['driver_id'])}',
            ),
          ),
      heading('Comunidad'),
      ...users.map(
        (u) => panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${u['name']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${roleLabels[u['role']]} · ${u['active'] == true ? 'Activo' : 'Suspendido'}'
                '${u['role'] == 'driver' ? ' · ${u['available'] == true ? 'Conectado' : 'Desconectado'}' : ''}'
                '${u['rating_avg'] != null ? ' · ★ ${u['rating_avg']}' : ''}',
              ),
              if (u['id'] != me!['id'] && u['role'] != 'admin')
                TextButton(
                  onPressed: busy
                      ? null
                      : () => command('admin_set_active', {
                          'p_id': u['id'],
                          'p_active': u['active'] != true,
                        }),
                  child: Text(
                    u['active'] == true
                        ? 'Suspender acceso'
                        : 'Reactivar acceso',
                  ),
                ),
            ],
          ),
        ),
      ),
      heading('Vehículos registrados'),
      ...vehicles.map(
        (v) => panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${v['plate']} · ${v['brand']} ${v['model']}\n${person(v['driver_id'])} · ${v['color']}',
              ),
              TextButton(
                onPressed: busy ? null : () => editVehicle(v),
                child: const Text('Editar vehículo'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget metric(String value, String label) => SizedBox(
    width: 130,
    child: Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );

  List<Widget> history() {
    final mine = role == 'admin'
        ? trips
        : trips
              .where(
                (t) =>
                    t['passenger_id'] == me!['id'] ||
                    t['driver_id'] == me!['id'],
              )
              .toList();
    final spent = mine
        .where((t) => t.tripStatus == 'completed')
        .fold(0, (s, t) => s + (t.fareCents ?? 0));
    return [
      heading(
        role == 'admin' ? 'Todos los servicios' : 'Mis viajes',
        role == 'driver'
            ? 'Ganancias acumuladas: ${formatCop(spent)}'
            : role == 'passenger'
            ? 'Total en viajes: ${formatCop(spent)}'
            : 'Historial de todos los servicios.',
      ),
      if (mine.isEmpty) panel(const Text('Aún no hay viajes registrados.')),
      ...mine.map(
        (t) => TripHistoryCard(
          trip: t,
          paid: payments.any(
            (p) => p['trip_id'] == t['id'] && p['status'] == 'APPROVED',
          ),
          counterpart: role == 'passenger'
              ? (t['driver_id'] == null
                    ? null
                    : 'Conductor: ${person(t['driver_id'])}')
              : role == 'driver'
              ? 'Pasajero: ${person(t['passenger_id'])}'
              : null,
          actions: [
            if (t.isActiveTrip && role != 'admin')
              FilledButton.tonal(
                onPressed: () => setState(() => tab = 0),
                child: const Text('Ver en el mapa'),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> profile() {
    final car = vehicles.where((v) => v['driver_id'] == me!['id']).firstOrNull;
    return [
      heading('Mi cuenta', '${roleLabels[role]} en RideMove'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: mist,
                  child: Text(
                    '${me!['name']}'.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${me!['name']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        [
                          if ('${me!['phone'] ?? ''}'.isNotEmpty)
                            '${me!['phone']}',
                          if (me!['document_number'] != null)
                            '${me!['document_type'] ?? 'CC'} ${me!['document_number']}',
                          if (me!['rating_avg'] != null)
                            '★ ${me!['rating_avg']} (${me!['rating_count']})',
                        ].join(' · '),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : editProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar información'),
            ),
          ],
        ),
      ),
      if (role == 'driver') ...[
        heading('Mi vehículo'),
        if (car != null)
          panel(
            Row(
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 34,
                  color: ink,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${car['brand']} ${car['model']} · ${car['color']}\nPlaca ${car['plate']} · Licencia ${car['license']}',
                  ),
                ),
              ],
            ),
          ),
        button(
          car == null ? 'Registrar vehículo' : 'Editar vehículo',
          editVehicle,
          icon: Icons.directions_car_outlined,
        ),
      ],
      const SizedBox(height: 24),
      if (repo.demo)
        const Text(
          'Modo demostración · Datos temporales. Cierra sesión para entrar con otro rol.',
          style: TextStyle(color: muted),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : logout,
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      ),
    ];
  }

  Future<void> logout() async {
    await act(() async {
      sessionEpoch++;
      await widget.tracker?.stop();
      if (role == 'driver' && me?['available'] == true) {
        try {
          await repo.command('set_availability', {'p_available': false});
        } catch (_) {}
      }
      await repo.signOut();
      setState(() {
        me = null;
        trips = users = vehicles = locations = payments = [];
        tab = 0;
        password.clear();
        loadError = null;
      });
    });
  }

  Future<void> editProfile() async {
    await editForm(
      'Editar perfil',
      {'name': '${me!['name']}', 'phone': '${me!['phone'] ?? ''}'},
      {'name': 'Nombre completo', 'phone': 'Celular'},
      (values) => repo.command('save_profile', {
        'p_name': values['name'],
        'p_phone': values['phone'],
      }),
    );
  }

  Future<void> editVehicle([JsonRow? managed]) async {
    final v =
        managed ??
        vehicles.where((v) => v['driver_id'] == me!['id']).firstOrNull ??
        {};
    await editForm(
      'Mi vehículo',
      {
        for (final k in ['plate', 'brand', 'model', 'color', 'license'])
          k: '${v[k] ?? ''}',
      },
      {
        'plate': 'Placa',
        'brand': 'Marca y línea',
        'model': 'Modelo / año',
        'color': 'Color',
        'license': 'Licencia de conducción',
      },
      (values) => repo.command('save_vehicle', {
        if (managed != null) 'p_driver_id': managed['driver_id'],
        for (final e in values.entries) 'p_${e.key}': e.value,
      }),
    );
  }

  Future<void> editForm(
    String title,
    Map<String, String> initial,
    Map<String, String> labels,
    Future<void> Function(Map<String, String>) save,
  ) async {
    final controllers = initial.map(
      (k, v) => MapEntry(k, TextEditingController(text: v)),
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries
                .map((e) => field(e.value, labels[e.key]!))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final values = controllers.map(
                (k, v) => MapEntry(k, v.text.trim()),
              );
              if (values.values.any((v) => v.isEmpty)) {
                message('Completa todos los campos.');
                return;
              }
              Navigator.pop(ctx, values);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Deja terminar la animación del diálogo antes de liberar los controladores.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers.values) {
      c.dispose();
    }
    if (result != null && mounted) {
      await act(() => save(result), success: 'Guardado.');
    }
  }
}
