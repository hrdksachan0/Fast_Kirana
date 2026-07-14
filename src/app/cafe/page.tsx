import { redirect } from 'next/navigation'

export default async function CafePage() {
  redirect('/?mode=cafe')
}
