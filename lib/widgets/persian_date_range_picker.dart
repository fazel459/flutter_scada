//lib/widgets/persian_date_range_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_scada/utils/persian-datetime-picker/lib/persian_datetime_picker.dart';
import 'package:flutter_scada/utils/shamsi_date/lib/shamsi_date.dart';
import '../utils/persian_utils.dart';

class PersianDateRangePicker extends StatefulWidget {
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(DateTime? from, DateTime? to) onRangeChanged;

  const PersianDateRangePicker({
    super.key,
    this.fromDate,
    this.toDate,
    required this.onRangeChanged,
  });

  @override
  State<PersianDateRangePicker> createState() => _PersianDateRangePickerState();
}

class _PersianDateRangePickerState extends State<PersianDateRangePicker> {
  Future<void> _showPicker(BuildContext context) async {

// showDialog(context: context, builder:(context) => Dialog(child: Container(height: 400,width: 300,color: Colors.blue,),), );
    var picked = await showPersianDateRangePicker(
      
      context: context,
      barrierColor: Colors.blue.withValues(alpha: 0.5),
      initialDateRange: JalaliRange(
        start: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 7))),
        end: Jalali.now(),
      ),
      firstDate: Jalali(1385, 8),
      lastDate: Jalali(1450, 9),
      initialDate: Jalali.now(),
    );
    if(picked != null) {
      widget.onRangeChanged(picked.start.toDateTime(), picked.end.toDateTime());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF10B981)),
            const SizedBox(width: 12),
            Expanded(
              child: widget.fromDate != null && widget.toDate != null
                  ? Row(
                      children: [
                        Text(
                          PersianUtils.formatJalaliNumeric(widget.fromDate!),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Text(
                          ' تا ',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        Text(
                          PersianUtils.formatJalaliNumeric(widget.toDate!),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  : const Text(
                      'انتخاب بازه زمانی...',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
            ),
            // if (widget.fromDate != null || widget.toDate != null)
            //   IconButton(
            //     icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
            //     onPressed: () => widget.onRangeChanged(null, null),
            //   ),
          ],
        ),
      ),
    );
  }
}
