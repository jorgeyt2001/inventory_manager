import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/formatters.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReservationProvider>().loadReservations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservas')),
      body: Consumer<ReservationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.reservations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay reservas', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateReservation(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Reserva'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.reservations.length,
            itemBuilder: (context, index) {
              final reservation = provider.reservations[index];
              return _buildReservationCard(reservation);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateReservation(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    Color statusColor;
    IconData statusIcon;
    switch (reservation.status) {
      case 'completada':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelada':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(30),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(reservation.productName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${reservation.customerName}'),
            Row(
              children: [
                if (reservation.color != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Text(reservation.color!,
                        style: TextStyle(fontSize: 11, color: Colors.purple[700])),
                  ),
                if (reservation.talla != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo[200]!),
                    ),
                    child: Text('Talla ${reservation.talla!}',
                        style: TextStyle(fontSize: 11, color: Colors.indigo[700])),
                  ),
                Text('x${reservation.quantity}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(AppFormatters.dateTime(reservation.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        trailing: reservation.status == 'pendiente'
            ? PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'completada',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Completar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cancelada',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Cancelar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    context.read<ReservationProvider>().deleteReservation(reservation.id);
                  } else {
                    context.read<ReservationProvider>().updateStatus(reservation.id, value);
                  }
                },
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reservation.status.substring(0, 1).toUpperCase() +
                      reservation.status.substring(1),
                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
        isThreeLine: true,
      ),
    );
  }

  void _showCreateReservation(BuildContext context) {
    final nameController = TextEditingController();
    final customerController = TextEditingController();
    final phoneController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    String? selectedColor;
    String? selectedTalla;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Nueva Reserva'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo / Producto *',
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedColor,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          prefixIcon: Icon(Icons.palette),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('--')),
                          ...Product.coloresSelene.map((c) =>
                              DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (v) => setState(() => selectedColor = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedTalla,
                        decoration: const InputDecoration(
                          labelText: 'Talla',
                          prefixIcon: Icon(Icons.straighten),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('--')),
                          ...Product.tallasSelene.map((t) =>
                              DropdownMenuItem(value: t, child: Text(t))),
                        ],
                        onChanged: (v) => setState(() => selectedTalla = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customerController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || customerController.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Producto y cliente son requeridos')),
                  );
                  return;
                }

                context.read<ReservationProvider>().addReservation(
                  productName: nameController.text,
                  color: selectedColor,
                  talla: selectedTalla,
                  quantity: int.tryParse(quantityController.text) ?? 1,
                  customerName: customerController.text,
                  customerPhone: phoneController.text.isEmpty ? null : phoneController.text,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reserva creada')),
                );
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
