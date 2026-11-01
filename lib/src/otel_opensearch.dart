// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_opensearch_suppression.dart';

const _tracerName = 'dartastic_otel_libs_opensearch';
const _systemValue = 'opensearch';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedOpensearchSearch` callback.
class OpensearchSearchResult<T> {
  /// Creates a result.
  const OpensearchSearchResult({
    required this.value,
    this.totalHits,
    this.tookMs,
  });

  /// The value returned to the caller.
  final T value;
  final int? totalHits;
  final int? tookMs;
}

/// Wraps an OpenSearch `_search` query in a CLIENT span.
Future<T> tracedOpensearchSearch<T>({
  required String index,
  required Future<OpensearchSearchResult<T>> Function() invoke,
  String? domain,
  String? region,
  int? size,
}) async {
  if (opensearchInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'search',
    'db.collection.name': index,
    'opensearch.index': index,
  };
  if (domain != null) m['opensearch.domain'] = domain;
  if (region != null) m['cloud.region'] = region;
  if (size != null) m['opensearch.size'] = size;

  final span = _tracer().startSpan(
    'opensearch search $index',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.totalHits != null) {
      extras.add(OTelAPI.attributeInt('opensearch.hits.total', r.totalHits!));
    }
    if (r.tookMs != null) {
      extras.add(OTelAPI.attributeInt('opensearch.took_ms', r.tookMs!));
    }
    if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
