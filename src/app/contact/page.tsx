import { Metadata } from 'next'
import { MapPin, Phone, Mail, Clock, MessageSquare } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Contact Us - FastKirana',
  description: 'Get in touch with FastKirana customer support for order queries, store partnerships, and rider assistance in Ghatampur.',
}

export default function ContactPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto space-y-8">
        
        {/* Header */}
        <div className="text-center space-y-3">
          <h1 className="text-3xl sm:text-4xl font-black text-foreground tracking-tight">
            We&apos;re Here to Help
          </h1>
          <p className="text-muted-foreground text-sm sm:text-base max-w-xl mx-auto">
            Have a question about your order, delivery timing, or want to partner with us? Reach out through any of the channels below.
          </p>
        </div>

        {/* Contact Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          
          {/* Phone & WhatsApp */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-xs flex flex-col items-center text-center space-y-4">
            <div className="h-12 w-12 rounded-2xl bg-rose-500/10 text-rose-600 flex items-center justify-center">
              <Phone className="h-6 w-6" />
            </div>
            <div>
              <h3 className="font-bold text-foreground text-lg">Call &amp; WhatsApp</h3>
              <p className="text-xs text-muted-foreground mt-1">Instant assistance for active orders</p>
            </div>
            <a 
              href="https://wa.me/917054470303" 
              target="_blank" 
              rel="noopener noreferrer"
              className="mt-auto inline-flex items-center gap-2 bg-rose-600 hover:bg-rose-700 text-white text-xs sm:text-sm font-bold px-4 py-2.5 rounded-xl transition-all shadow-xs"
            >
              <MessageSquare className="h-4 w-4" />
              +91 70544 70303
            </a>
          </div>

          {/* Email Support */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-xs flex flex-col items-center text-center space-y-4">
            <div className="h-12 w-12 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center">
              <Mail className="h-6 w-6" />
            </div>
            <div>
              <h3 className="font-bold text-foreground text-lg">Email Support</h3>
              <p className="text-xs text-muted-foreground mt-1">For business queries &amp; refunds</p>
            </div>
            <a 
              href="mailto:fastkiranadelivery@gmail.com"
              className="mt-auto inline-flex items-center gap-2 bg-muted hover:bg-muted/80 text-foreground text-xs sm:text-sm font-bold px-4 py-2.5 rounded-xl border border-border transition-all"
            >
              fastkiranadelivery@gmail.com
            </a>
          </div>

          {/* Operating Hours */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-xs flex flex-col items-center text-center space-y-4">
            <div className="h-12 w-12 rounded-2xl bg-amber-500/10 text-amber-600 flex items-center justify-center">
              <Clock className="h-6 w-6" />
            </div>
            <div>
              <h3 className="font-bold text-foreground text-lg">Operating Hours</h3>
              <p className="text-xs text-muted-foreground mt-1">365 Days a Year</p>
            </div>
            <div className="mt-auto text-xs sm:text-sm font-black text-amber-600 dark:text-amber-400 bg-amber-500/10 border border-amber-500/20 px-3 py-2 rounded-xl">
              6:00 AM – 12:00 Midnight
            </div>
          </div>
        </div>

        {/* Physical Office / Dark Store Hub */}
        <div className="bg-card border border-border rounded-2xl p-6 sm:p-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 text-rose-600 text-xs font-black uppercase tracking-wider bg-rose-500/10 px-2.5 py-1 rounded-lg">
              <MapPin className="h-3.5 w-3.5" />
              Central Operations Hub
            </div>
            <h3 className="text-lg sm:text-xl font-bold text-foreground">
              FastKirana Dark Store &amp; Logistics Center
            </h3>
            <p className="text-sm text-muted-foreground leading-relaxed">
              NH34, Ghatampur Market, Kanpur Nagar, Uttar Pradesh - 209206
            </p>
          </div>
          <a
            href="https://maps.google.com/?q=Ghatampur,Kanpur+Nagar"
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 bg-foreground text-background text-xs sm:text-sm font-bold px-5 py-3 rounded-xl hover:opacity-90 transition-all"
          >
            Open in Maps ↗
          </a>
        </div>

      </div>
    </div>
  )
}
