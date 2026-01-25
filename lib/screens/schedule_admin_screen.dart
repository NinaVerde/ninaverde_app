import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_model.dart';
import '../services/schedule_service.dart';
import '../widgets/nv_widgets.dart'; 
import 'schedule_editor_screen.dart';

class ScheduleAdminScreen extends StatefulWidget {
  const ScheduleAdminScreen({super.key});

  @override
  State<ScheduleAdminScreen> createState() => _ScheduleAdminScreenState();
}

class _ScheduleAdminScreenState extends State<ScheduleAdminScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme base
      appBar: const NvAppBar(
        title: 'Staff Scheduling',
        extraActions: [],
      ),
      body: StreamBuilder<List<ScheduleModel>>(
        stream: ScheduleService.getSchedulesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final schedules = snapshot.data ?? [];
          
          if (schedules.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return _buildScheduleCard(schedule);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSchedule,
        label: const Text('New Schedule'),
        icon: const Icon(Icons.calendar_month),
        backgroundColor: const Color(0xFF00FF94), // Accessing nvGreen manually if needed, or use Theme
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'No Schedules Yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new weekly schedule to get started.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    final dateFormat = DateFormat('MMM d');
    final rangeText = '${dateFormat.format(schedule.startDate)} - ${dateFormat.format(schedule.endDate)}';
    
    // Status color
    Color statusColor;
    String statusText = schedule.status.name.toUpperCase();
    switch (schedule.status) {
      case ScheduleStatus.published:
        statusColor = const Color(0xFF00FF94); // nvGreen
        break;
      case ScheduleStatus.draft:
        statusColor = Colors.orangeAccent;
        break;
      case ScheduleStatus.archived:
        statusColor = Colors.grey;
        break;
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _openScheduleEditor(schedule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    schedule.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    rangeText,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Metadata stats (Elite touch)
              Row(
                children: [
                   _buildStatBadge(Icons.access_time, '${schedule.totalHoursBudgeted.toStringAsFixed(0)}h Budgeted'),
                   const SizedBox(width: 12),
                   _buildStatBadge(Icons.people, 'Staff Assigned'), // Placeholder for real logic
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
           Icon(icon, size: 14, color: Colors.grey[500]),
           const SizedBox(width: 4),
           Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  void _createNewSchedule() async {
    // Quick dialog to set name and startDate
    final DateTime now = DateTime.now();
    // Round to next Monday? Or just today. Let's say next Monday for "Elite" smartness default.
    // ... logic for next monday ...
    
    DateTime selectedDate = now;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECT START DATE (MONDAY)',
    );
    
    if (picked != null) {
      // Create default Week schedule
      final endDate = picked.add(const Duration(days: 6)); // 7 days total
      final weekNum =  _getWeekNumber(picked);
      
      final newSchedule = ScheduleModel(
        id: '', // Auto-gen by service
        name: 'Week $weekNum - ${DateFormat('yyyy').format(picked)}',
        startDate: picked,
        endDate: endDate,
        createdAt: DateTime.now(),
        createdBy: 'Admin', // TODO: Get actual user name
      );
      
      final id = await ScheduleService.createSchedule(newSchedule);
      // Open editor
      // ignore: use_build_context_synchronously
      _openScheduleEditor(newSchedule.copyWith(id: id));
    }
  }

  void _openScheduleEditor(ScheduleModel schedule) {
     Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScheduleEditorScreen(schedule: schedule)));
  }
  
  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}

// Minimal NvAppBar stub if not found, but it should be there.
// If NvAppBar is not exported by nv_widgets.dart, we might need to import it specifically.
// Based on previous file listing, it is likely in nv_widgets.dart or we need to find it.
