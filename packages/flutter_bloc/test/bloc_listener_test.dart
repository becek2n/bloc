import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CounterEvent { increment }

class CounterBloc extends Bloc<CounterEvent, int> {
  @override
  int get initialState => 0;

  @override
  Stream<int> mapEventToState(CounterEvent event) async* {
    switch (event) {
      case CounterEvent.increment:
        yield state + 1;
        break;
    }
  }
}

class MyApp extends StatefulWidget {
  final BlocWidgetListener<int> onListenerCalled;

  MyApp({Key key, this.onListenerCalled}) : super(key: key);

  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CounterBloc _counterBloc;
  int count = 0;

  @override
  void initState() {
    super.initState();
    _counterBloc = CounterBloc();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: BlocListener(
          bloc: _counterBloc,
          listener: (BuildContext context, int state) {
            widget.onListenerCalled?.call(context, state);
          },
          child: Column(
            children: [
              Text('count: $count'),
              RaisedButton(
                key: Key('bloc_listener_reset_button'),
                child: Text('Reset Bloc'),
                onPressed: () {
                  setState(() {
                    _counterBloc = CounterBloc();
                  });
                },
              ),
              RaisedButton(
                key: Key('bloc_listener_noop_button'),
                child: Text('Noop Bloc'),
                onPressed: () {
                  setState(() {
                    _counterBloc = _counterBloc;
                  });
                },
              ),
              RaisedButton(
                key: Key('bloc_listener_increment_button'),
                child: Text('Increment Bloc'),
                onPressed: () {
                  _counterBloc.add(CounterEvent.increment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('BlocListener', () {
    testWidgets('throws if initialized with null bloc, listener, and child',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(
          BlocListener<Bloc, dynamic>(
            bloc: null,
            listener: null,
            child: null,
          ),
        );
        fail('should throw AssertionError');
      } on Object catch (error) {
        expect(error, isAssertionError);
      }
    });

    testWidgets('throws if initialized with null listener and child',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(
          BlocListener<CounterBloc, int>(
            bloc: CounterBloc(),
            listener: null,
            child: null,
          ),
        );
        fail('should throw AssertionError');
      } on Object catch (error) {
        expect(error, isAssertionError);
      }
    });

    testWidgets('renders child properly', (WidgetTester tester) async {
      final targetKey = Key('bloc_listener_container');
      await tester.pumpWidget(
        BlocListener(
          bloc: CounterBloc(),
          listener: (BuildContext context, int state) {},
          child: Container(
            key: targetKey,
          ),
        ),
      );
      expect(find.byKey(targetKey), findsOneWidget);
    });

    testWidgets('calls listener on single state change',
        (WidgetTester tester) async {
      int latestState;
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
            latestState = state;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 1);
        expect(latestState, 1);
      });
    });

    testWidgets('calls listener on multiple state change',
        (WidgetTester tester) async {
      int latestState;
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1, 2];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
            latestState = state;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 2);
        expect(latestState, 2);
      });
    });

    testWidgets(
        'updates when the bloc is changed at runtime to a different bloc and unsubscribes from old bloc',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      int latestState;
      final incrementFinder = find.byKey(Key('bloc_listener_increment_button'));
      final resetBlocFinder = find.byKey(Key('bloc_listener_reset_button'));
      await tester.pumpWidget(MyApp(
        onListenerCalled: (BuildContext context, int state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(resetBlocFinder);
      await tester.pumpAndSettle();
      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 3);
      expect(latestState, 1);
    });

    testWidgets(
        'does not update when the bloc is changed at runtime to same bloc and stays subscribed to current bloc',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      int latestState;
      final incrementFinder = find.byKey(Key('bloc_listener_increment_button'));
      final noopBlocFinder = find.byKey(Key('bloc_listener_noop_button'));
      await tester.pumpWidget(MyApp(
        onListenerCalled: (BuildContext context, int state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(noopBlocFinder);
      await tester.pumpAndSettle();
      await tester.tap(incrementFinder);
      await tester.pumpAndSettle();
      expect(listenerCallCount, 3);
      expect(latestState, 3);
    });

    testWidgets(
        'calls condition on single state change with correct previous and current states',
        (WidgetTester tester) async {
      int latestPreviousState;
      int latestState;
      var conditionCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) {
            conditionCallCount++;
            latestPreviousState = previous;
            latestState = state;
            return true;
          },
          listener: (BuildContext context, int state) {},
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(conditionCallCount, 1);
        expect(latestPreviousState, 0);
        expect(latestState, 1);
      });
    });

    testWidgets(
        'calls condition with previous listener state and current bloc state',
        (WidgetTester tester) async {
      int latestPreviousState;
      int latestState;
      var conditionCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1, 2, 3];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) {
            conditionCallCount++;
            if ((previous + state) % 3 == 0) {
              latestPreviousState = previous;
              latestState = state;
              return true;
            }
            return false;
          },
          listener: (BuildContext context, int state) {},
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(conditionCallCount, 3);
        expect(latestPreviousState, 1);
        expect(latestState, 2);
      });
    });

    testWidgets('infers the bloc from the context if the bloc is not provided',
        (WidgetTester tester) async {
      int latestPreviousState;
      int latestState;
      var conditionCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1];
      await tester.pumpWidget(
        BlocProvider.value(
          value: counterBloc,
          child: BlocListener<CounterBloc, int>(
            condition: (int previous, int state) {
              conditionCallCount++;
              latestPreviousState = previous;
              latestState = state;

              return true;
            },
            listener: (BuildContext context, int state) {},
            child: Container(),
          ),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(conditionCallCount, 1);
        expect(latestPreviousState, 0);
        expect(latestState, 1);
      });
    });

    testWidgets(
        'calls condition on multiple state change with correct previous and current states',
        (WidgetTester tester) async {
      int latestPreviousState;
      int latestState;
      var conditionCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1, 2];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) {
            conditionCallCount++;
            latestPreviousState = previous;
            latestState = state;

            return true;
          },
          listener: (BuildContext context, int state) {},
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);

      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(conditionCallCount, 2);
        expect(latestPreviousState, 1);
        expect(latestState, 2);
      });
    });

    testWidgets(
        'does not call listener when condition returns false on single state change',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) => false,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 0);
      });
    });

    testWidgets(
        'calls listener when condition returns true on single state change',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) => true,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 1);
      });
    });

    testWidgets(
        'does not call listener when condition returns false on multiple state changes',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1, 2, 3, 4];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) => false,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 0);
      });
    });

    testWidgets(
        'calls listener when condition returns true on multiple state change',
        (WidgetTester tester) async {
      var listenerCallCount = 0;
      final counterBloc = CounterBloc();
      final expectedStates = [0, 1, 2, 3, 4];
      await tester.pumpWidget(
        BlocListener(
          bloc: counterBloc,
          condition: (int previous, int state) => true,
          listener: (BuildContext context, int state) {
            listenerCallCount++;
          },
          child: Container(),
        ),
      );
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      counterBloc.add(CounterEvent.increment);
      expectLater(counterBloc, emitsInOrder(expectedStates)).then((_) {
        expect(listenerCallCount, 4);
      });
    });
  });
}
