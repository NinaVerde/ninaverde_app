import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_model.dart';
import '../models/shift_model.dart';
import '../models/user_profile_model.dart';
import '../services/schedule_service.dart';
import '../services/staff_service.dart';
import '../widgets/nv_widgets.dart';

class ScheduleEditorScreen extends StatefulWidget {
  final ScheduleModel schedule;

  const ScheduleEditorScreen({super.key, required this.schedule});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> with SingleTickerProviderStateMixin {
  late DateTime _currentDate;
  late TabController _tabController;
  final List<DateTime> _days = [];
  
  final Map<String, UserProfile> _staffCache = {};

  @override
  void initState() {
    super.initState();
    _currentDate = widget.schedule.startDate;
    // Generate dates for tabs (Schedule duration)
    DateTime runner = widget.schedule.startDate;
    while (runner.isBefore(widget.schedule.endDate.add(const Duration(days: 1)))) {
      _days.add(runner);
      runner = runner.add(const Duration(days: 1));
    }
    _tabController = TabController(length: _days.length, vsync: this);
    _loadStaff();
  }
  
  Future<void> _loadStaff() async {
      // Pre-fetch staff for displaying names/roles nicely
      try {
          // Assuming getAllStaffStream returns a stream, we can listen or just get once.
          // For editor, one-off fetch might be okay, but stream is safer for updates. 
          // Let's use the stream logic inside the dialog, but cache here for the list view if needed.
           // Actually, the shift model stores assigneeName denormalized, so we might not strictly need full cache for list.
           // But good to have for avatar urls etc.
      } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: NvAppBar(
        title: widget.schedule.name,
        showBack: true,
        extraActions: [
           if (!widget.schedule.isPublished) ...[
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Smart Fill (Auto-Assign)',
              onPressed: _runSmartFill,
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Publish Schedule',
              onPressed: _publishSchedule,
            ),
           ],
        ],
      ),
      body: Column(
        children: [
            _buildDateTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _days.map((date) => _TimelineScheduleView(
                  scheduleId: widget.schedule.id,
                  date: date,
                  onEditShift: _openShiftDialog,
                )).toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openShiftDialog(null),
        backgroundColor: const Color(0xFF00FF94),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
  
  Widget _buildDateTabs() {
    return Container(
      color: Colors.grey[900],
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF00FF94),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF00FF94),
        onTap: (index) {
          setState(() {
            _currentDate = _days[index];
          });
        },
        tabs: _days.map((date) {
            return Tab(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                         Text(DateFormat('EEE').format(date).toUpperCase(), style: const TextStyle(fontSize: 12)),
                         Text(DateFormat('d').format(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                ),
            );
        }).toList(),
      ),
    );
  }

  void _openShiftDialog(ShiftModel? existingShift) async {
    await showDialog(
      context: context,
      builder: (_) => ShiftEditorDialog(
        scheduleId: widget.schedule.id,
        initialDate: _currentDate, // Default to currently selected tab
        existingShift: existingShift,
      ),
    );
  }
  
  void _publishSchedule() async {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Publish Schedule?'),
              content: const Text('This will make shifts visible to all staff. Notifications will be sent.'),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
              ],
          ),
      );
      
      if (confirm == true) {
          await ScheduleService.publishSchedule(widget.schedule.id);
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule Published!')));
              setState(() {}); // refresh state if needed (model updated in firestore, stream in prev screen handles it mostly)
          }
      }
  }

    void _runSmartFill() async {
        final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Row(children: [Icon(Icons.auto_fix_high, color: Color(0xFF00FF94)), SizedBox(width: 8), Text('Smart Fill?')]),
                content: const Text('John AI will automatically assign all OPEN shifts to available staff based on their roles and workload balance.\n\nExisting assignments will not be changed.'),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Auto-Assign')),
                ],
            ),
        );
        
        if (confirm == true) {
            // Show loading
            if (mounted) {
                showDialog(
                    context: context, 
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF94)))
                );
            }
            
            await Future.delayed(const Duration(seconds: 2)); // Fake "Thinking" time for razzle dazzle
            
            final count = await ScheduleService.autoAssignShifts(widget.schedule.id);
            
            if (mounted) {
                Navigator.pop(context); // Close loader
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('John AI assigned $count shifts!'),
                        backgroundColor: const Color(0xFF00FF94),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        action: SnackBarAction(label: 'Nice!', textColor: Colors.black, onPressed: (){}),
                    )
                );
            }
        }
    }
}

class _TimelineScheduleView extends StatelessWidget {
  final String scheduleId;
  final DateTime date;
  final Function(ShiftModel) onEditShift;

  const _TimelineScheduleView({
    required this.scheduleId, 
    required this.date,
    required this.onEditShift,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShiftModel>>(
      stream: ScheduleService.getShiftsForSchedule(scheduleId),
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
         }
         final allShifts = snapshot.data ?? [];
         final dayShifts = allShifts.where((s) {
             return s.startTime.year == date.year && 
                    s.startTime.month == date.month && 
                    s.startTime.day == date.day;
         }).toList();
         
         // 1. Group by Role
         final Map<StaffRole, List<ShiftModel>> grouped = {};
         for (var role in StaffRole.values) {
             final inRole = dayShifts.where((s) => s.role == role).toList();
             if (inRole.isNotEmpty) {
                 grouped[role] = inRole;
             }
         }

         return Column(
             children: [
                 // "John's Insight" HUD
                 _buildJohnsInsightHud(dayShifts),
                 
                 Expanded(
                     child: SingleChildScrollView(
                         scrollDirection: Axis.vertical,
                         child: SingleChildScrollView(
                             scrollDirection: Axis.horizontal,
                             child: _buildGanttChart(grouped),
                         ),
                     ),
                 ),
             ],
         );
      },
    );
  }
  
  Widget _buildJohnsInsightHud(List<ShiftModel> shifts) {
      double totalHours = shifts.fold(0, (sum, s) => sum + s.hours);
      double estCost = totalHours * 3.50; // Mock avg rate $3.50/hr
      
      return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.black]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FF94).withOpacity(0.3)),
              boxShadow: [
                  BoxShadow(color: const Color(0xFF00FF94).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ]
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Row(
                      children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF00FF94), size: 20),
                          const SizedBox(width: 8),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text("JOHN'S INSIGHT", style: TextStyle(color: Color(0xFF00FF94), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                  Text("${shifts.length} Shifts • ${totalHours.toStringAsFixed(1)} Hrs", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                          ),
                      ],
                  ),
                  Row(
                      children: [
                          _buildHudMetric("Labor", "\$${estCost.toStringAsFixed(0)}"),
                          const SizedBox(width: 16),
                          _buildHudMetric("Sales (Est)", "\$2,400", color: const Color(0xFF00FF94)),
                      ],
                  ),
              ],
          ),
      );
  }
  
  Widget _buildHudMetric(String label, String value, {Color color = Colors.grey}) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
              Text(label.toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 9)),
              Text(value, style: TextStyle(color: color == Colors.grey ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
      );
  }

  Widget _buildGanttChart(Map<StaffRole, List<ShiftModel>> grouped) {
      // Configuration
      const double hourWidth = 60.0;
      const double rowHeight = 70.0;
      const int startHour = 6; // 6 AM
      const int endHour = 26; // 2 AM next day
      const int totalHours = endHour - startHour;
      
      return Stack(
          children: [
              // 1. Grid Background
              Row(
                  children: List.generate(totalHours, (i) {
                      final h = startHour + i;
                      final displayH = h > 24 ? h - 24 : (h > 12 ? h - 12 : h);
                      final amPm = h >= 12 && h < 24 ? 'PM' : 'AM';
                      
                      return Container(
                          width: hourWidth,
                          height: (grouped.length * rowHeight) + 40, // rows + header
                          decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.grey[800]!, width: 0.5)),
                          ),
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('$displayH $amPm', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                              ),
                          ),
                      );
                  }),
              ),
              
              // 2. Rows & Shifts
              Padding(
                  padding: const EdgeInsets.only(top: 40), // Below header
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                          return Container(
                              height: rowHeight,
                              width: totalHours * hourWidth,
                              decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey[900]!)),
                              ),
                              child: Stack(
                                  children: [
                                      // Row Label (Sticky-ish simulation)
                                      // ideally sticky, but for now absolute left? No, horizontal scroll moves it.
                                      // We will just let it scroll for now or put it in HUD? 
                                      // Let's put a subtle watermark icon for the role
                                      Positioned(
                                          left: 10,
                                          top: 10,
                                          child: Opacity(
                                              opacity: 0.1, 
                                              child: Text(entry.key.name.toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))
                                          ),
                                      ),
                                      
                                      // Shifts
                                      ...entry.value.map((shift) {
                                          double start = (shift.startTime.hour + (shift.startTime.minute/60)) - startHour;
                                          if (start < 0) start += 24; // handle weird wrap? not usually for 6am start
                                          
                                          double duration = shift.duration.inMinutes / 60.0;
                                          
                                          return Positioned(
                                              left: start * hourWidth,
                                              top: 10,
                                              width: duration * hourWidth,
                                              height: rowHeight - 20,
                                              child: _TimelineShiftCard(shift: shift, onTap: () => onEditShift(shift)),
                                          );
                                      }),
                                  ],
                              ),
                          );
                      }).toList(),
                  ),
              ),
              
              // 3. Current Time Indicator
              _CurrentTimeLine(startHour: startHour, hourWidth: hourWidth, totalHeight: (grouped.length * rowHeight) + 40),
          ],
      );
  }
}

class _CurrentTimeLine extends StatelessWidget {
    final int startHour;
    final double hourWidth;
    final double totalHeight;
    
    const _CurrentTimeLine({required this.startHour, required this.hourWidth, required this.totalHeight});
    
    @override
    Widget build(BuildContext context) {
        final now = DateTime.now();
        double h = now.hour + (now.minute / 60.0);
        if (h < startHour) return const SizedBox.shrink(); // Before view
        
        final double pos = (h - startHour) * hourWidth;
        
        return Positioned(
            left: pos,
            top: 0,
            bottom: 0,
            child: Container(
               width: 2,
               height: totalHeight,
               color: const Color(0xFFFF5252),
               child: Stack(
                   clipBehavior: Clip.none,
                   children: [
                       Positioned(
                           top: 0,
                           left: -4,
                           child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle)),
                       )
                   ],
               ),
            ),
        );
    }
}

class _TimelineShiftCard extends StatelessWidget {
    final ShiftModel shift;
    final VoidCallback onTap;
    
    const _TimelineShiftCard({required this.shift, required this.onTap});
    
    @override
    Widget build(BuildContext context) {
        final bool isOpen = shift.userId == null;
        final color = shift.color ?? const Color(0xFF00FF94);
        
        return Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                    decoration: BoxDecoration(
                        color: isOpen ? Colors.transparent : color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isOpen ? Colors.orange.withOpacity(0.5) : color,
                            width: 1,
                            style: isOpen ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        // Elite: Glassmorphism gradient
                        gradient: isOpen ? null : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                                color.withOpacity(0.3),
                                color.withOpacity(0.1),
                            ]
                        )
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Text(
                                isOpen ? "OPEN" : (shift.assigneeName ?? "Unknown"),
                                style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                            ),
                            Text(
                                "${DateFormat('h:mm').format(shift.startTime)}-${DateFormat('h:mm').format(shift.endTime)}",
                                style: TextStyle(
                                    color: Colors.grey[300], 
                                    fontSize: 10,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}

class ShiftEditorDialog extends StatefulWidget {
  final String scheduleId;
  final DateTime initialDate;
  final ShiftModel? existingShift;

  const ShiftEditorDialog({
    super.key,
    required this.scheduleId,
    required this.initialDate,
    this.existingShift,
  });

  @override
  State<ShiftEditorDialog> createState() => _ShiftEditorDialogState();
}

class _ShiftEditorDialogState extends State<ShiftEditorDialog> {
    final _formKey = GlobalKey<FormState>();
    
    late StaffRole _role;
    UserProfile? _selectedStaff;
    late DateTime _startDetails; // Combined Date+Time
    late TimeOfDay _startTime;
    late TimeOfDay _endTime;
    final TextEditingController _notesCtrl = TextEditingController();
    
    List<UserProfile> _allStaff = [];
    
    @override
    void initState() {
        super.initState();
        
        // Defaults
        final shift = widget.existingShift;
        if (shift != null) {
            _role = shift.role;
            _startDetails = shift.startTime;
            _startTime = TimeOfDay.fromDateTime(shift.startTime);
            _endTime = TimeOfDay.fromDateTime(shift.endTime);
            _notesCtrl.text = shift.notes ?? '';
            // We need to match staff ID later once list loads
        } else {
            _role = StaffRole.server;
            _startDetails = widget.initialDate; // Date from tab
            _startTime = const TimeOfDay(hour: 9, minute: 0);
            _endTime = const TimeOfDay(hour: 17, minute: 0); // 5 PM
        }
        
        _loadStaff();
    }
    
    Future<void> _loadStaff() async {
        // Fetch all staff
        // Note: In a real app we might optimize this query
        final stream = StaffService.getAllStaffStream();
        final staff = await stream.first; 
        if (mounted) {
            setState(() {
                _allStaff = staff;
                if (widget.existingShift?.userId != null) {
                     try {
                         _selectedStaff = staff.firstWhere((s) => s.uid == widget.existingShift!.userId);
                     } catch (_) {}
                }
            });
        }
    }

    @override
    Widget build(BuildContext context) {
        return AlertDialog(
            title: Text(widget.existingShift == null ? 'Add Shift' : 'Edit Shift'),
            content: SizedBox(
                width: 400,
                child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                // 1. Role Selection
                                DropdownButtonFormField<StaffRole>(
                                    initialValue: _role,
                                    decoration: const InputDecoration(labelText: 'Role'),
                                    items: StaffRole.values.map((r) => DropdownMenuItem(
                                        value: r, 
                                        child: Text(r.name.toUpperCase())
                                    )).toList(),
                                    onChanged: (val) => setState(() => _role = val!),
                                ),
                                const SizedBox(height: 16),
                                
                                // 2. Staff Selection (Optional -> Open Shift)
                                DropdownButtonFormField<UserProfile?>(
                                    initialValue: _selectedStaff,
                                    decoration: const InputDecoration(
                                        labelText: 'Staff Member', 
                                        helperText: 'Leave empty for Open Shift',
                                    ),
                                    items: [
                                        const DropdownMenuItem<UserProfile?>(value: null, child: Text('OPEN SHIFT')),
                                        ..._allStaff.map((u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u.displayName.isNotEmpty ? u.displayName : u.email),
                                        )),
                                    ],
                                    onChanged: (val) => setState(() => _selectedStaff = val),
                                ),
                                const SizedBox(height: 16),
                                
                                // 3. Times
                                Row(
                                    children: [
                                        Expanded(child: _buildTimePicker('Start', _startTime, (t) => setState(() => _startTime = t))),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildTimePicker('End', _endTime, (t) => setState(() => _endTime = t))),
                                    ],
                                ),
                                const SizedBox(height: 16),
                                
                                // 4. Notes
                                TextFormField(
                                    controller: _notesCtrl,
                                    decoration: const InputDecoration(labelText: 'Notes', hintText: 'e.g. Closing duties'),
                                    maxLines: 2,
                                ),
                            ],
                        ),
                    ),
                ),
            ),
            actions: [
                if (widget.existingShift != null)
                    TextButton(
                        onPressed: _deleteShift,
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                    ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                    onPressed: _saveShift,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FF94), foregroundColor: Colors.black),
                    child: const Text('Save'),
                ),
            ],
        );
    }
    
    Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onPick) {
        return InkWell(
            onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) onPick(picked);
            },
            child: InputDecorator(
                decoration: InputDecoration(labelText: label),
                child: Text(time.format(context)),
            ),
        );
    }
    
    void _saveShift() async {
        if (!_formKey.currentState!.validate()) return;
        
        // Construct DateTimes
        // Use initialDate (from tab) for year/month/day
        final date = widget.initialDate;
        final startDt = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
        // Be careful with end time if it crosses midnight. For now assume same day.
        var endDt = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);
        
        if (endDt.isBefore(startDt)) {
            // Assume next day
            endDt = endDt.add(const Duration(days: 1));
        }

        // Color coding based on role? Or random?
        // Let's hardcode some role colors for elite feel
        int color;
        switch (_role) {
            case StaffRole.manager: color = 0xFF9C27B0; break; // Purple
            case StaffRole.cook: 
            case StaffRole.kitchen: color = 0xFFF44336; break; // Red
            case StaffRole.server: color = 0xFF2196F3; break; // Blue
            case StaffRole.bartender: color = 0xFFE91E63; break; // Pink
            case StaffRole.driver: color = 0xFFFF9800; break; // Orange
            default: color = 0xFF4CAF50; // Green
        }
        
        final shift = ShiftModel(
            id: widget.existingShift?.id ?? '', // New if empty
            scheduleId: widget.scheduleId,
            userId: _selectedStaff?.uid,
            assigneeName: _selectedStaff?.displayName,
            role: _role,
            startTime: startDt,
            endTime: endDt,
            status: _selectedStaff == null ? ShiftStatus.open : ShiftStatus.assigned,
            notes: _notesCtrl.text.trim(),
            colorInt: color,
        );
        
        if (widget.existingShift == null) {
            await ScheduleService.addShift(shift);
        } else {
            await ScheduleService.updateShift(shift);
        }
        
        if (mounted) Navigator.pop(context);
    }
    
    void _deleteShift() async {
        if (widget.existingShift == null) return;
        await ScheduleService.deleteShift(widget.existingShift!.id);
        if (mounted) Navigator.pop(context);
    }
}
