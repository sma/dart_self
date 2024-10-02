coverage/report.txt: lib/*.dart test/*.dart
	@mkdir -p coverage
	@dart run coverage:test_with_coverage >coverage/log 2>&1 -- --no-color || awk '/^Consider enabling the flag/{exit} {print}' coverage/log
	@dart run coverage:format_coverage -i coverage/coverage.json -o coverage/report.txt

clean:
	rm -rf coverage
