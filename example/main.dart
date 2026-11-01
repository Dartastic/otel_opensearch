// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_opensearch/otel_opensearch.dart';

/// Traces Opensearch calls with OpenTelemetry.
///
/// `otel_opensearch` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Opensearch call in
/// [tracedOpensearchSearch]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'opensearch-example');

  // Wraps an OpenSearch _search query in a CLIENT span.
  final opensearchSearchId = await tracedOpensearchSearch<String>(
    index: 'products',
    domain: 'example',
    region: 'us-east-1',
    size: 512,
    invoke: () async {
      // Make the Opensearch call here, then report what it returned.
      const id = 'opensearch_8f3a2c';
      return const OpensearchSearchResult(value: id, totalHits: 1, tookMs: 120);
    },
  );
  OTelLog.info('tracedOpensearchSearch returned $opensearchSearchId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutOpensearchInstrumentationAsync.
  await runWithoutOpensearchInstrumentationAsync(
    () => tracedOpensearchSearch<String>(
      index: 'products',
      domain: 'example',
      region: 'us-east-1',
      size: 512,
      invoke: () async {
        const id = 'opensearch_8f3a2c';
        return const OpensearchSearchResult(
            value: id, totalHits: 1, tookMs: 120);
      },
    ),
  );

  await OTel.shutdown();
}
