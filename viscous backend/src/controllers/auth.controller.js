import jwt from 'jsonwebtoken';
import { firestoreDb } from '../config/firebaseAdmin.js';

export const login = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Query Firestore for user with matching phone
    const usersRef = firestoreDb.collection('users');
    const querySnapshot = await usersRef.where('phone', '==', phone).limit(1).get();

    if (querySnapshot.empty) {
      return res.status(401).json({
        success: false,
        message: 'User not found with this phone number'
      });
    }

    // Get user data
    const userDoc = querySnapshot.docs[0];
    const userData = userDoc.data();
    
    // Create user object with id
    const user = {
      id: userDoc.id,
      ...userData
    };

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id,
        phone: user.phone,
        role: user.role,
        route: user.route,
        userstop: user.userstop ?? null
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      token,
      user
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};
