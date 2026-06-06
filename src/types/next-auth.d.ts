import { DefaultSession } from 'next-auth'

declare module 'next-auth' {
  interface User {
    id?: string
    role?: 'USER' | 'PICKER' | 'CHEF' | 'DELIVERY' | 'ADMIN'
    phone?: string | null
  }

  interface Session {
    user: {
      id?: string
      role?: 'USER' | 'PICKER' | 'CHEF' | 'DELIVERY' | 'ADMIN'
      phone?: string | null
    } & DefaultSession['user']
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    id?: string
    role?: 'USER' | 'PICKER' | 'CHEF' | 'DELIVERY' | 'ADMIN'
    phone?: string | null
  }
}
