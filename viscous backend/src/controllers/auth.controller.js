import jwt from 'jsonwebtoken';
import { dbA, dbB } from '../config/firebaseAdmin.js';
import { logger } from '../utils/logger.js';

export const login = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone || !String(phone).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    const phoneStr = String(phone);

    // Validate phone number format (only digits, spaces, dashes, parentheses, and optional leading +)
    if (!/^\+?[0-9\s\-()]+$/.test(phoneStr)) {
      return res.status(400).json({
        success: false,
        message: 'Phone number must contain only numeric digits'
      });
    }

    // Normalize incoming phone number (strip spaces, dashes, parentheses)
    const cleanPhone = phoneStr.replace(/[\s\-\(\)]/g, "");

    // Generate phone variations to handle country codes (+91, 91, 0 prefix)
    let phoneVariations = [cleanPhone];
    if (cleanPhone.length >= 10) {
      const base10 = cleanPhone.slice(-10);
      phoneVariations = [
        base10,
        `+91${base10}`,
        `91${base10}`,
        `0${base10}`
      ];
    }
    const uniqueVariations = Array.from(new Set(phoneVariations));

    // Query Project A Firestore for user with matching phone using 'in' operator
    let querySnapshot = await dbA.firestoreDb.collection('users')
      .where('phone', 'in', uniqueVariations)
      .limit(1)
      .get();
    let fleet = 'A';

    // If not found in Project A and Project B is configured and different, search Project B
    if (querySnapshot.empty && dbB !== dbA) {
      querySnapshot = await dbB.firestoreDb.collection('users')
        .where('phone', 'in', uniqueVariations)
        .limit(1)
        .get();
      fleet = 'B';
    }

    if (querySnapshot.empty) {
      return res.status(401).json({
        success: false,
        message: 'User not found with this phone number'
      });
    }

    // Get user data
    const userDoc = querySnapshot.docs[0];
    const userData = userDoc.data();
    
    // Create user object with id and fleet
    const user = {
      id: userDoc.id,
      fleet,
      ...userData
    };

    // Generate JWT token including fleet (no expiration)
    const token = jwt.sign(
      { 
        userId: user.id,
        phone: user.phone,
        role: user.role,
        route: user.route,
        userstop: user.userstop ?? null,
        fleet: user.fleet
      },
      process.env.JWT_SECRET
    );

    res.json({
      success: true,
      token,
      user
    });

  } catch (error) {
    logger.error('Login error', { error: error.message });
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};
