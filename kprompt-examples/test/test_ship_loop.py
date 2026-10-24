import pytest
from kprompt-examples.ship_loop import ShipLoop, SpendCapExceeded

def survivor_selector_all(candidates):
    # Simple survivor selector: select all candidates
    return candidates

def survivor_selector_best_value(candidates):
    # Select survivors with highest value first until spend cap reached
    sorted_candidates = sorted(candidates, key=lambda f: f['value'], reverse=True)
    return sorted_candidates

def test_ship_under_spend_cap():
    loop = ShipLoop(monthly_spend_cap=100, survivor_selector=survivor_selector_all)
    features = [
        {'name': 'feat1', 'cost': 30, 'value': 10},
        {'name': 'feat2', 'cost': 50, 'value': 20},
    ]
    for f in features:
        loop.add_candidate(f)
    shipped = loop.ship()
    assert len(shipped) == 2
    assert loop.spend_this_month == 80
    assert all(f in loop.shipped_features for f in shipped)

def test_ship_exceed_spend_cap_raises():
    loop = ShipLoop(monthly_spend_cap=50, survivor_selector=survivor_selector_all)
    features = [
        {'name': 'feat1', 'cost': 30, 'value': 10},
        {'name': 'feat2', 'cost': 50, 'value': 20},
    ]
    for f in features:
        loop.add_candidate(f)
    with pytest.raises(SpendCapExceeded):
        loop.ship()

def test_ship_partial_survivor_selection():
    # Survivor selector picks only features with value >= 15
    def survivor_selector_value_15(candidates):
        return [f for f in candidates if f['value'] >= 15]

    loop = ShipLoop(monthly_spend_cap=100, survivor_selector=survivor_selector_value_15)
    features = [
        {'name': 'feat1', 'cost': 30, 'value': 10},
        {'name': 'feat2', 'cost': 50, 'value': 20},
        {'name': 'feat3', 'cost': 40, 'value': 25},
    ]
    for f in features:
        loop.add_candidate(f)
    shipped = loop.ship()
    # Only feat2 and feat3 selected, total cost 90 < 100
    assert len(shipped) == 2
    assert loop.spend_this_month == 90
    assert all(f['value'] >= 15 for f in shipped)

def test_reset_month_clears_state():
    loop = ShipLoop(monthly_spend_cap=100, survivor_selector=survivor_selector_all)
    feature = {'name': 'feat1', 'cost': 30, 'value': 10}
    loop.add_candidate(feature)
    shipped = loop.ship()
    assert loop.spend_this_month == 30
    loop.reset_month()
    assert loop.spend_this_month == 0
    assert loop.shipped_features == []
    assert loop.candidates == []

def test_no_candidates_no_ship():
    loop = ShipLoop(monthly_spend_cap=100, survivor_selector=survivor_selector_all)
    shipped = loop.ship()
    assert shipped == []
