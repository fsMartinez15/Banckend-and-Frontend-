import 'package:flutter/material.dart';
import 'ride_theme.dart';

class TripRequestSheet extends StatefulWidget {
  final TextEditingController origin, destination;
  const TripRequestSheet({
    super.key,
    required this.origin,
    required this.destination,
  });
  @override
  State<TripRequestSheet> createState() => _TripRequestSheetState();
}

class _TripRequestSheetState extends State<TripRequestSheet> {
  final form = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        10,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Arma tu recorrido',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                'Un punto de partida. Un nuevo plan.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: widget.origin,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '¿Dónde te recogemos?',
                  hintText: 'Dirección o lugar de encuentro',
                  prefixIcon: Icon(
                    Icons.radio_button_checked_rounded,
                    color: electric,
                  ),
                ),
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Escribe un punto de partida de al menos 3 caracteres.'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Intercambiar origen y destino',
                  onPressed: () {
                    final value = widget.origin.text;
                    widget.origin.text = widget.destination.text;
                    widget.destination.text = value;
                  },
                  icon: const Icon(Icons.swap_vert_rounded, color: electric),
                ),
              ),
              TextFormField(
                controller: widget.destination,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿A dónde quieres ir?',
                  hintText: 'Dirección o destino',
                  prefixIcon: Icon(Icons.place_rounded, color: orange),
                ),
                validator: (v) {
                  if ((v ?? '').trim().length < 3) {
                    return 'Escribe un destino de al menos 3 caracteres.';
                  }
                  if (v!.trim().toLowerCase() ==
                      widget.origin.text.trim().toLowerCase()) {
                    return 'Elige un destino distinto al origen.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escribe lugares de Fusagasugá y confirma los detalles con tu conductor.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.near_me_rounded, size: 20),
                  label: const Text('Confirmar solicitud'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
