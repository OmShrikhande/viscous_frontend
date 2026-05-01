import * as routeService from "../services/route.service.js";

export const getRoute = async (req, res) => {
  try {
    const { routeNumber } = req.params;
    
    if (!routeNumber) {
      return res.status(400).json({ error: "Route number is required" });
    }

    const route = await routeService.getRouteByNumber(routeNumber);
    
    if (!route) {
      return res.status(404).json({ error: "Route not found" });
    }

    res.status(200).json({ success: true, data: route });
  } catch (error) {
    console.error("Error fetching route:", error);
    res.status(500).json({ error: "Internal server error" });
  }
};
