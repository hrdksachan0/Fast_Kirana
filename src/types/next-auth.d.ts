import { DefaultSession } from 'next-auth'

declare module 'next-auth' {
  interface User {
    id?: string
    role?: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
    phone?: string | null
    assignedRestaurantId?: string | null
    assignedStoreId?: string | null
    needsPhoneVerification?: boolean
  }

  interface Session {
    user: {
      id?: string
      role?: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
      phone?: string | null
      assignedRestaurantId?: string | null
      assignedStoreId?: string | null
      needsPhoneVerification?: boolean
    } & DefaultSession['user']
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    id?: string
    role?: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
    phone?: string | null
    assignedRestaurantId?: string | null
    assignedStoreId?: string | null
    needsPhoneVerification?: boolean
  }
}
