import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/ride_repository.dart';
import '../application/location_tracker.dart';
import '../domain/external_navigation.dart';
import '../domain/route_planner.dart';
import 'trip_navigation_screen.dart';
import 'driver_map.dart';
import 'city_map.dart';
import 'ride_theme.dart';
import 'welcome_map_hero.dart';
import 'passenger_home.dart';
import 'trip_request_sheet.dart';
import 'package:latlong2/latlong.dart';

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
  List<JsonRow> trips = [], users = [], vehicles = [], locations = [];
  bool busy = false, registering = false, loading = false;
  String? loadError;
  int tab = 0;
  String registerRole = 'passenger';
  Timer? timer;
  int sessionEpoch = 0;
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final origin = TextEditingController(), destination = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (repo.signedIn) {
      refresh();
    }
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (me != null && !busy) {
        refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tracker?.stop();
    timer?.cancel();
    for (final c in [email, password, name, origin, destination]) {
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
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (loading) {
      return;
    }
    loading = true;
    final epoch = sessionEpoch;
    if (!silent && mounted) {
      setState(() {});
    }
    try {
      final profile = await repo.profile();
      if (profile['active'] != true) {
        await widget.tracker?.stop();
        if (mounted && epoch == sessionEpoch) {
          setState(() {
            me = profile;
            trips = [];
            users = [];
            vehicles = [];
            locations = [];
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
      ]);
      if (mounted && epoch == sessionEpoch && repo.signedIn) {
        setState(() {
          me = profile;
          trips = data[0];
          users = data[1];
          vehicles = data[2];
          locations = data[3];
          loadError = null;
        });
        if (!data[0].any(
          (t) =>
              t['driver_id'] == profile['id'] &&
              ['accepted', 'in_progress'].contains(t['status']),
        )) {
          await widget.tracker?.stop();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loadError =
              'No pudimos actualizar los datos. Revisa tu conexión y la migración de Supabase.';
        });
      }
    } finally {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> act(Future<void> Function() action, {String? success}) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      await action();
      if (repo.signedIn) {
        await refresh();
      }
      if (success != null) {
        message(success);
      }
    } on AppFailure catch (e) {
      message(e.message);
    } catch (e) {
      message(
        e is StateError
            ? e.message
            : 'No se pudo completar la acción. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> command(String name, JsonRow params) =>
      act(() => repo.command(name, params));
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
      boxShadow: const [
        BoxShadow(
          color: Color(0x0515233D),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: secret,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
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
        logged && me!['active'] == true && role == 'passenger' && tab == 0;
    return Scaffold(
      appBar: AppBar(
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
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: mist,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy || loading) const LinearProgressIndicator(minHeight: 2),
            if (loadError != null)
              MaterialBanner(
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
                        setState(() {
                          loadError = null;
                        });
                      },
                      child: const Text('Volver'),
                    ),
                ],
              ),
            Expanded(
              child: mapHome
                  ? passengerMapHome()
                  : Center(
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
                                : home(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: logged
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() {
                tab = v;
              }),
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    role == 'admin'
                        ? Icons.space_dashboard_outlined
                        : Icons.explore_outlined,
                  ),
                  selectedIcon: Icon(
                    role == 'admin'
                        ? Icons.space_dashboard_rounded
                        : Icons.explore_rounded,
                  ),
                  label: role == 'admin' ? 'Panel' : 'Inicio',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Viajes',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Mi perfil',
                ),
              ],
            )
          : null,
    );
  }

  Widget passengerMapHome() {
    final active = trips
        .where((r) => ['accepted', 'in_progress'].contains(r['status']))
        .firstOrNull;
    final position = active == null
        ? null
        : locations
              .where((p) => p['driver_id'] == active['driver_id'])
              .firstOrNull;
    return PassengerHome(
      name: me!['name'].toString().split(' ').first,
      driver: position == null
          ? null
          : LatLng(
              (position['latitude'] as num).toDouble(),
              (position['longitude'] as num).toDouble(),
            ),
      onRequest: busy ? null : requestTrip,
      onDestination: (place) {
        destination.text = place;
        requestTrip();
      },
      activeTrips: activeTrips(),
    );
  }

  Future<void> requestTrip() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (_) =>
          TripRequestSheet(origin: origin, destination: destination),
    );
    if (confirmed != true || !mounted) return;
    await act(
      () async {
        await repo.command('create_trip', {
          'p_origin': origin.text.trim(),
          'p_destination': destination.text.trim(),
        });
        origin.clear();
        destination.clear();
      },
      success:
          'Solicitud creada. Te avisaremos aquí cuando un conductor la acepte.',
    );
  }

  List<Widget> auth() => [
    const WelcomeMapHero(),
    heading(
      repo.demo
          ? 'Explora RideMove'
          : registering
          ? 'Crea tu cuenta'
          : 'Qué bueno verte',
      repo.demo
          ? 'Prueba el flujo con datos de ejemplo. Los cambios se conservan solo durante esta sesión.'
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
      if (registering) field(name, 'Nombre completo'),
      field(email, 'Correo electrónico', keyboard: TextInputType.emailAddress),
      field(password, 'Contraseña', secret: true),
      if (registering)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'passenger', label: Text('Pasajero')),
              ButtonSegment(value: 'driver', label: Text('Conductor')),
            ],
            selected: {registerRole},
            onSelectionChanged: (s) => setState(() {
              registerRole = s.first;
            }),
          ),
        ),
      button(registering ? 'Crear cuenta' : 'Iniciar sesión', () {
        if (!RegExp(
              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
            ).hasMatch(email.text.trim()) ||
            password.text.length < 8 ||
            (registering && name.text.trim().length < 2)) {
          message(
            'Escribe un correo válido, una contraseña de al menos 8 caracteres y tu nombre.',
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
            );
            if (!ready) {
              message(
                'Revisa tu correo para confirmar la cuenta y luego inicia sesión.',
              );
              setState(() {
                registering = false;
              });
            }
          } else {
            await repo.signIn(email.text.trim(), password.text);
          }
        });
      }),
      TextButton(
        onPressed: () => setState(() {
          registering = !registering;
        }),
        child: Text(
          registering ? 'Ya tengo una cuenta' : 'Soy nuevo, crear cuenta',
        ),
      ),
    ],
  ];
  List<Widget> home() => [
    Text(
      'FUSAGASUGÁ  •  ${roleLabels[role]?.toUpperCase()}',
      style: const TextStyle(
        color: electric,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    ),
    heading(
      'Hola, ${me!['name'].toString().split(' ').first} 👋',
      role == 'passenger'
          ? '¿A dónde vamos hoy?'
          : role == 'driver'
          ? 'Conecta con tu ciudad, un viaje a la vez.'
          : 'Así se mueve nuestra comunidad.',
    ),
    if (role == 'driver') ...[
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(height: 220, child: CityMap(controls: false)),
      ),
      const SizedBox(height: 16),
      panel(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            me!['available'] == true
                ? 'Estás disponible'
                : 'Estás desconectado',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Recibe solicitudes cuando quieras conducir'),
          value: me!['available'] == true,
          onChanged: busy
              ? null
              : (v) => command('set_availability', {'p_available': v}),
        ),
        color: mist,
      ),
      button(
        'Activar ubicación durante el viaje',
        shareLocation,
        icon: Icons.my_location,
      ),
      TextButton(
        onPressed: () async {
          await widget.tracker?.stop();
          message('Ubicación detenida.');
        },
        child: const Text('Detener ubicación'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Con un viaje activo se actualiza al desplazarte, mientras la app está abierta. Al salir de la app se detiene; vuelve a activarla al regresar.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      heading('Tu viaje actual'),
      ...activeTrips(),
      heading(
        'Solicitudes en tu ciudad',
        'Solicitudes de Fusagasugá, sin ordenar por distancia.',
      ),
      if (me!['available'] == true)
        ...trips.where((r) => r['status'] == 'pending').map(tripCard)
      else
        panel(const Text('Activa tu disponibilidad para aceptar un viaje.')),
    ],
    if (role == 'admin') ...[
      panel(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            metric('${users.length}', 'Usuarios'),
            metric('${trips.length}', 'Viajes'),
            metric(
              '${trips.where((r) => r['status'] == 'completed').length}',
              'Finalizados',
            ),
          ],
        ),
        color: mist,
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
                '${roleLabels[u['role']]} · ${u['active'] == true ? 'Activo' : 'Suspendido'}',
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
    ],
  ];
  Widget metric(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
  List<Widget> activeTrips() {
    final active = trips
        .where(
          (r) =>
              !['completed', 'cancelled'].contains(r['status']) &&
              (role != 'driver' || r['driver_id'] == me!['id']),
        )
        .toList();
    return active.isEmpty
        ? [
            panel(
              const Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, color: electric),
                  SizedBox(width: 14),
                  Expanded(child: Text('Todo listo para tu próximo viaje.')),
                ],
              ),
            ),
          ]
        : active.map(tripCard).toList();
  }

  List<Widget> history() => [
    heading(
      role == 'admin' ? 'Todos los servicios' : 'Mis viajes',
      'Consulta el estado y el historial de tus servicios.',
    ),
    if (trips.isEmpty) panel(const Text('Aún no hay viajes registrados.')),
    ...trips.map(tripCard),
  ];
  Widget tripCard(JsonRow r) {
    final s = r['status'];
    final car = vehicles
        .where((v) => v['driver_id'] == r['driver_id'])
        .firstOrNull;
    final position = locations
        .where((v) => v['driver_id'] == r['driver_id'])
        .firstOrNull;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statusLabels[s] ?? s,
                  style: const TextStyle(
                    color: electric,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (r['rating'] != null)
                Text(
                  '★ ${r['rating']}',
                  style: const TextStyle(color: electric),
                ),
            ],
          ),
          const SizedBox(height: 16),
          routeLine(Icons.radio_button_checked, '${r['origin']}'),
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text('│', style: TextStyle(color: Colors.grey)),
          ),
          routeLine(Icons.location_on, '${r['destination']}'),
          const SizedBox(height: 12),
          Text(
            'Solicitud: ${r['created_at'].toString().substring(0, 10)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (r['driver_id'] != null) ...[
            const Divider(height: 28),
            Text('Conductor: ${person(r['driver_id'])}'),
            if (car != null)
              Text('${car['brand']} · ${car['color']} · ${car['plate']}'),
            if (position != null && ['accepted', 'in_progress'].contains(s))
              Text(
                'Última ubicación: ${position['latitude']}, ${position['longitude']}\nActualizada: ${position['updated_at']}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
          if (position != null && ['accepted', 'in_progress'].contains(s))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: DriverMap(
                latitude: (position['latitude'] as num).toDouble(),
                longitude: (position['longitude'] as num).toDouble(),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (role == 'passenger' && s == 'pending')
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => command('transition_trip', {
                          'p_id': r['id'],
                          'p_status': 'cancelled',
                        }),
                  child: const Text('Cancelar solicitud'),
                ),
              if (role == 'driver' &&
                  s == 'pending' &&
                  me!['available'] == true) ...[
                button(
                  'Aceptar',
                  () => command('transition_trip', {
                    'p_id': r['id'],
                    'p_status': 'accepted',
                  }),
                  icon: Icons.check,
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => command('reject_trip', {'p_id': r['id']}),
                  child: const Text('Rechazar'),
                ),
              ],
              if (role == 'driver' &&
                  r['driver_id'] == me!['id'] &&
                  s == 'accepted')
                button('Iniciar viaje', () => startTrip(r)),
              if (role == 'driver' &&
                  r['driver_id'] == me!['id'] &&
                  s == 'in_progress')
                button(
                  'Abrir navegación',
                  () => openNavigation(r),
                  icon: Icons.navigation_rounded,
                ),
              if (role == 'driver' &&
                  r['driver_id'] == me!['id'] &&
                  s == 'in_progress')
                button(
                  'Finalizar viaje',
                  () => command('transition_trip', {
                    'p_id': r['id'],
                    'p_status': 'completed',
                  }),
                  icon: Icons.flag_outlined,
                ),
              if (role == 'passenger' &&
                  s == 'completed' &&
                  r['rating'] == null)
                button(
                  'Calificar viaje',
                  () => rate(r),
                  icon: Icons.star_outline,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget routeLine(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 21, color: electric),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ],
  );
  List<Widget> profile() => [
    heading('Mi perfil', '${roleLabels[role]} en RideMove'),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: mist,
            child: Text(
              me!['name'].toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 24, color: ink),
            ),
          ),
          const SizedBox(height: 16),
          Text('${me!['name']}', style: Theme.of(context).textTheme.titleLarge),
          Text('${me!['phone'] ?? ''}'),
          const SizedBox(height: 16),
          button('Editar información', editProfile, icon: Icons.edit_outlined),
        ],
      ),
    ),
    if (role == 'driver') ...[
      heading('Mi vehículo'),
      if (vehicles.where((v) => v['driver_id'] == me!['id']).firstOrNull
          case final JsonRow v)
        panel(
          Text(
            '${v['brand']} ${v['model']} · ${v['color']}\nPlaca: ${v['plate']}\nLicencia: ${v['license']}',
          ),
        ),
      button(
        'Registrar o editar vehículo',
        editVehicle,
        icon: Icons.directions_car_outlined,
      ),
    ],
    const SizedBox(height: 24),
    if (repo.demo)
      const Text(
        'Modo demostración · Datos temporales. Puedes cambiar de rol cerrando sesión para completar un viaje.',
      ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: busy ? null : logout,
      icon: const Icon(Icons.logout),
      label: const Text('Cerrar sesión'),
    ),
  ];
  Future<void> logout() async {
    await act(() async {
      sessionEpoch++;
      await widget.tracker?.stop();
      await repo.signOut();
      setState(() {
        me = null;
        trips = [];
        users = [];
        vehicles = [];
        locations = [];
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
      {'name': 'Nombre completo', 'phone': 'Teléfono'},
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
        'brand': 'Marca',
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
    // Let the dialog finish its closing animation before disposing its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers.values) {
      c.dispose();
    }
    if (result != null && mounted) {
      await act(() => save(result));
    }
  }

  Future<void> rate(JsonRow trip) async {
    int stars = 5;
    final comment = TextEditingController();
    final result = await showDialog<JsonRow>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('¿Cómo estuvo tu viaje?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    tooltip: '${i + 1} estrellas',
                    onPressed: () => update(() {
                      stars = i + 1;
                    }),
                    icon: Icon(
                      i < stars ? Icons.star : Icons.star_outline,
                      color: electric,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Después'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'p_id': trip['id'],
                'p_rating': stars,
                'p_comment': comment.text.trim(),
              }),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    comment.dispose();
    if (result != null && mounted) {
      await command('rate_trip', result);
    }
  }

  Future<void> shareLocation() => act(() async {
    if (!trips.any(
      (t) =>
          t['driver_id'] == me!['id'] &&
          ['accepted', 'in_progress'].contains(t['status']),
    )) {
      throw StateError('Acepta un viaje antes de compartir tu ubicación.');
    }
    if (widget.tracker == null) {
      throw StateError('Ubicación no disponible en esta sesión.');
    }
    await widget.tracker!.start(onError: message);
  }, success: 'Ubicación activada para el viaje actual.');

  Future<void> startTrip(JsonRow trip) async {
    bool started = false;
    await act(() async {
      await repo.command('transition_trip', {
        'p_id': trip['id'],
        'p_status': 'in_progress',
      });
      started = true;
    });
    if (started && mounted) await openNavigation(trip);
  }

  Future<void> openNavigation(JsonRow trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripNavigationScreen(
          trip: trip,
          repository: repo,
          tracker: widget.tracker,
          navigation: widget.navigation,
          routePlanner: widget.routePlanner,
        ),
      ),
    );
    if (mounted) await refresh();
  }
}
