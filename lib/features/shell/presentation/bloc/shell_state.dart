part of 'shell_bloc.dart';

class ShellState extends Equatable {
  final int selectedIndex;

  const ShellState({required this.selectedIndex});

  ShellState copyWith({int? selectedIndex}) {
    return ShellState(selectedIndex: selectedIndex ?? this.selectedIndex);
  }

  @override
  List<Object?> get props => [selectedIndex];
}
