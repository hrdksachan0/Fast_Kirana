import { DefaultSession } from 'next-auth'

export type UserRole = 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN' | 'VENDOR'

declare module 'next-auth' {
  interface User {
    id?: string
    role?: UserRole
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
      role?: UserRole
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
    role?: UserRole
    phone?: string | null
    assignedRestaurantId?: string | null
    assignedStoreId?: string | null
    needsPhoneVerification?: boolean
    fastapiToken?: string
  }
}
