import time
import logging
from typing import Optional

logger = logging.getLogger(__name__)

class SpendCapExceeded(Exception):
    pass

class ShipLoop:
    """
    Autonomous ship loop to keep kprompt/kprompt-examples shipping real capabilities
    under a monthly spend cap with survivor selection.
    """

    def __init__(self, monthly_spend_cap: float, survivor_selector):
        """
        :param monthly_spend_cap: Maximum allowed spend per month in USD.
        :param survivor_selector: Callable that selects survivors from candidates.
        """
        self.monthly_spend_cap = monthly_spend_cap
        self.survivor_selector = survivor_selector
        self.spend_this_month = 0.0
        self.shipped_features = []
        self.candidates = []

    def add_candidate(self, feature):
        """
        Add a candidate feature to consider shipping.
        :param feature: dict with keys 'name', 'cost', 'value'
        """
        self.candidates.append(feature)
        logger.debug(f"Added candidate feature: {feature}")

    def _can_ship(self, cost: float) -> bool:
        """
        Check if shipping a feature with given cost is within spend cap.
        """
        can_ship = (self.spend_this_month + cost) <= self.monthly_spend_cap
        logger.debug(f"Checking can_ship: current spend {self.spend_this_month}, "
                     f"cost {cost}, cap {self.monthly_spend_cap} => {can_ship}")
        return can_ship

    def ship(self):
        """
        Run one iteration of the ship loop:
        - Select survivors from candidates
        - Ship survivors if within spend cap
        - Update spend and shipped features
        """
        if not self.candidates:
            logger.info("No candidates to ship.")
            return []

        survivors = self.survivor_selector(self.candidates)
        logger.debug(f"Survivors selected: {[f['name'] for f in survivors]}")

        shipped_now = []
        for feature in survivors:
            cost = feature.get('cost', 0)
            if self._can_ship(cost):
                self.ship_feature(feature)
                shipped_now.append(feature)
            else:
                logger.warning(f"Spend cap exceeded, cannot ship feature: {feature['name']}")
                raise SpendCapExceeded(f"Cannot ship {feature['name']}, spend cap exceeded.")

        # Remove shipped features from candidates
        self.candidates = [f for f in self.candidates if f not in shipped_now]

        return shipped_now

    def ship_feature(self, feature):
        """
        Ship the feature: update spend and shipped features list.
        """
        cost = feature.get('cost', 0)
        self.spend_this_month += cost
        self.shipped_features.append(feature)
        logger.info(f"Shipped feature '{feature['name']}' costing {cost}. Total spend: {self.spend_this_month}")

    def reset_month(self):
        """
        Reset spend and shipped features for a new month.
        """
        logger.info(f"Resetting month. Previous spend: {self.spend_this_month}, shipped features: {len(self.shipped_features)}")
        self.spend_this_month = 0.0
        self.shipped_features = []
        self.candidates = []
