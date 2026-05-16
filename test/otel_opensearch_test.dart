// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_opensearch/otel_opensearch.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_opensearch-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('search records CLIENT span', () async {
    await tracedOpensearchSearch<String>(
      index: 'orders',
      domain: 'prod-search',
      region: 'us-east-1',
      size: 25,
      invoke: () async => const OpensearchSearchResult(
        value: 'rows',
        totalHits: 10,
        tookMs: 2,
      ),
    );
    final a = attrsOf(spans.findSpanByName('opensearch search orders')!);
    expect(a['db.system'], 'opensearch');
    expect(a['db.collection.name'], 'orders');
    expect(a['opensearch.domain'], 'prod-search');
    expect(a['cloud.region'], 'us-east-1');
    expect(a['opensearch.size'], 25);
    expect(a['opensearch.hits.total'], 10);
    expect(a['opensearch.took_ms'], 2);
  });

  test('suppression skips spans', () async {
    await runWithoutOpensearchInstrumentationAsync(() async {
      await tracedOpensearchSearch<String>(
        index: 'i',
        invoke: () async => const OpensearchSearchResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('opensearch '), isEmpty);
  });
}
