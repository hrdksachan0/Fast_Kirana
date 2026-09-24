import { DefaultSession } from 'next-auth'

declare module 'next-auth' {
  interface User {
    id?: string
    role?: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
    phone?: string | null
    assignedRestaurantId?: string | null
    assignedStoreId?: string | null
    needsPhoneVerification?: boolean
    fastapiToken?: string
  }

  interface Session {
    fastapiToken?: string
    user: {
      id?: string
      role?: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
      phone?: string | null
      assignedRestaurantId?: string | null
      assignedStoreId?: string | null
      needsPhoneVerification?: boolean
      fastapiToken?: string
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
    fastapiToken?: string
  }
}
