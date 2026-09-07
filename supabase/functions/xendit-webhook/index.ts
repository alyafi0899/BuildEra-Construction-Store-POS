import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const XENDIT_WEBHOOK_TOKEN = Deno.env.get('XENDIT_WEBHOOK_TOKEN')

serve(async (req) => {
  try {
    // 1. Verify Xendit Webhook Token
    const xenditToken = req.headers.get('x-callback-token')
    if (xenditToken !== XENDIT_WEBHOOK_TOKEN) {
      console.error('Invalid Xendit Webhook Token')
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const body = await req.json()
    console.log('Received Xendit Webhook:', body)

    // 2. Extract data (Xendit Invoice Callback format)
    const { status, external_id } = body

    if (status === 'PAID') {
      // Handle Xendit Test Data (external_id: "Invoice_123124123" or similar)
      // The error "invalid input syntax for type uuid" happened because
      // Xendit test data doesn't match our real userId format.
      if (external_id.toLowerCase().startsWith('invoice')) {
        console.log('Received Xendit Test Webhook - Success Simulation')
        return new Response(JSON.stringify({ message: 'Test Success' }), { status: 200 })
      }

      const parts = external_id.split('_')
      if (parts.length < 2) {
        console.error('Invalid external_id format:', external_id)
        return new Response(JSON.stringify({ error: 'Invalid ID format' }), { status: 400 })
      }

      const userId = parts[0]
      const planType = parts[1]

      // 3. Initialize Supabase Admin Client
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // 4. Calculate Expiry
      const now = new Date()
      const expiry = new Date()
      if (planType === 'yearly') {
        expiry.setFullYear(now.getFullYear() + 1)
      } else {
        expiry.setMonth(now.getMonth() + 1)
      }

      // 5. Update Subscription Table
      const { error } = await supabaseAdmin
        .from('subscriptions')
        .upsert({
          user_id: userId,
          plan_type: planType,
          status: 'active',
          expires_at: expiry.toISOString(),
          updated_at: now.toISOString(),
          last_external_id: external_id,
        })

      if (error) {
        console.error('Error updating subscription:', error)
        return new Response(JSON.stringify({
          error: 'Database update failed',
          details: error.message,
          hint: error.hint
        }), { status: 500 })
      }

      console.log(`Successfully upgraded user ${userId} to ${planType}`)
    }

    return new Response(JSON.stringify({ message: 'Success' }), { status: 200 })
  } catch (err) {
    console.error('Webhook processing error:', err)
    return new Response(JSON.stringify({ error: err.message }), { status: 400 })
  }
})
