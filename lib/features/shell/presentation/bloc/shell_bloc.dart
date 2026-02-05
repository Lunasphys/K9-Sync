import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'shell_event.dart';
part 'shell_state.dart';

/// Bloc for main shell bottom navigation index.
class ShellBloc extends Bloc<ShellEvent, ShellState> {
  ShellBloc() : super(ShellState(selectedIndex: 0)) {
    on<ShellTabSelected>(_onTabSelected);
  }

  void _onTabSelected(ShellTabSelected event, Emitter<ShellState> emit) {
    emit(state.copyWith(selectedIndex: event.index));
  }
}
