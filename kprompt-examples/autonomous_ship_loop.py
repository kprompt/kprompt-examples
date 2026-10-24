import time
import logging
from typing import Callable, Optional

logger = logging.getLogger(__name__)

class MonthlySpendCapExceeded(Exception):
    pass

class AutonomousShipLoop:
    """
    Autonomous ship loop to keep kprompt/kprompt-examples shipping real capabilities
    under a monthly spend cap with survivor selection.
    """

    def __init__(
        self,
        spend_cap_usd: float,
        get_current_spend_usd: Callable[[], float],
        ship_callback: Callable[[], bool],
        survivor_selector: Callable[[], bool],
        check_interval_sec: int = 3600,
    ):
        """
        Args:
            spend_cap_usd: Monthly spend cap in USD.
            get_current_spend_usd: Function to get current spend in USD.
            ship_callback: Function to perform a ship iteration. Returns True if shipped.
            survivor_selector: Function to decide if current iteration survives (returns True).
            check_interval_sec: Interval between checks in seconds.
        """
        self.spend_cap_usd = spend_cap_usd
        self.get_current_spend_usd = get_current_spend_usd
        self.ship_callback = ship_callback
        self.survivor_selector = survivor_selector
        self.check_interval_sec = check_interval_sec
        self.active = False

    def start(self, max_iterations: Optional[int] = None):
        """
        Start the autonomous ship loop.

        Args:
            max_iterations: Optional max number of iterations to run.
        """
        self.active = True
        iteration = 0
        logger.info("Starting autonomous ship loop with spend cap $%.2f", self.spend_cap_usd)
        while self.active:
            current_spend = self.get_current_spend_usd()
            logger.debug("Current spend: $%.2f", current_spend)
            if current_spend >= self.spend_cap_usd:
                logger.warning("Monthly spend cap exceeded: $%.2f >= $%.2f", current_spend, self.spend_cap_usd)
                raise MonthlySpendCapExceeded(f"Spend cap ${self.spend_cap_usd} exceeded with current spend ${current_spend}")

            shipped = self.ship_callback()
            logger.info("Ship iteration %d shipped: %s", iteration + 1, shipped)

            if shipped:
                survived = self.survivor_selector()
                logger.info("Survivor selection for iteration %d: %s", iteration + 1, survived)
                if not survived:
                    logger.info("Iteration %d did not survive, stopping loop.", iteration + 1)
                    self.active = False
                    break

            iteration += 1
            if max_iterations is not None and iteration >= max_iterations:
                logger.info("Reached max iterations %d, stopping loop.", max_iterations)
                break

            time.sleep(self.check_interval_sec)

    def stop(self):
        """
        Stop the autonomous ship loop.
        """
        self.active = False
        logger.info("Autonomous ship loop stopped by user.")
