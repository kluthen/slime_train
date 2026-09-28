extends GutTest
## Chunk 0 smoke test. It only proves that the runner finds tests, runs them
## headless and reports a failure through its exit code.


func test_runner_reports_results() -> void:
	assert_eq(1 + 1, 2)
