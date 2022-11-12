coverage/report.txt: lib/*.dart test/*.dart
	dart run coverage:test_with_coverage
	dart run coverage:format_coverage -i coverage/coverage.json -o coverage/report.txt

clean:
	rm -rf coverage
