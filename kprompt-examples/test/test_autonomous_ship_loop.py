import pytest
from kprompt-examples.autonomous_ship_loop import AutonomousShipLoop, MonthlySpendCapExceeded

def test_autonomous_ship_loop_runs_and_stops(monkeypatch):
    spend = [0.0]
    def get_spend():
        return spend[0]

    ship_calls = []
    def ship_callback():
        ship_calls.append(True)
        return True

    survivor_calls = []
    def survivor_selector():
        survivor_calls.append(True)
        # Survive only first 2 iterations
        return len(survivor_calls) < 3

    # Patch time.sleep to avoid delay
    monkeypatch.setattr("time.sleep", lambda x: None)

    loop = AutonomousShipLoop(
        spend_cap_usd=100.0,
        get_current_spend_usd=get_spend,
        ship_callback=ship_callback,
        survivor_selector=survivor_selector,
        check_interval_sec=1,
    )

    loop.start(max_iterations=5)

    # Should have shipped 3 times (2 survived, 3rd iteration stops)
    assert len(ship_calls) == 3
    assert len(survivor_calls) == 3

def test_autonomous_ship_loop_respects_spend_cap(monkeypatch):
    spend = [99.0]
    def get_spend():
        return spend[0]

    def ship_callback():
        return True

    def survivor_selector():
        return True

    monkeypatch.setattr("time.sleep", lambda x: None)

    loop = AutonomousShipLoop(
        spend_cap_usd=100.0,
        get_current_spend_usd=get_spend,
        ship_callback=ship_callback,
        survivor_selector=survivor_selector,
        check_interval_sec=1,
    )

    # Should run once then raise on next iteration when spend exceeds cap
    spend[0] = 99.0
    # First iteration ok
    loop.start(max_iterations=1)

    # Increase spend to exceed cap
    spend[0] = 100.01
    with pytest.raises(MonthlySpendCapExceeded):
        loop.start(max_iterations=1)
