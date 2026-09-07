import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const XENDIT_WEBHOOK_TOKEN = Deno.env.get('XENDIT_WEBHOOK_TOKEN')

serve(async (req) => {
  try {
    const xenditToken = req.headers.get('x-callback-token')
    if (xenditToken !== XENDIT_WEBHOOK_TOKEN) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const body = await req.json()
    const { status, external_id, amount, payment_method, id: invoiceId } = body

    if (status === 'PAID') {
      if (external_id.toLowerCase().startsWith('invoice')) {
        return new Response(JSON.stringify({ message: 'Test Success' }), { status: 200 })
      }

      const parts = external_id.split('_')
      const userId = parts[0]
      const planType = parts[1]

      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // 1. Get current subscription to handle pro-rata
      const { data: currentSub } = await supabaseAdmin
        .from('subscriptions')
        .select('*')
        .eq('user_id', userId)
        .single()

      const now = new Date()
      let newExpiry = new Date()

      // 2. Logic for Accumulation (Pro-rata)
      if (currentSub && currentSub.expires_at) {
        const currentExpiry = new Date(currentSub.expires_at)
        // If current sub is still active, start new sub from current expiry
        if (currentExpiry > now) {
          newExpiry = currentExpiry
        }
      }

      // Add duration
      if (planType === 'yearly') {
        newExpiry.setFullYear(newExpiry.getFullYear() + 1)
      } else {
        newExpiry.setMonth(newExpiry.getMonth() + 1)
      }

      // 3. Grace Period (3 days)
      const gracePeriod = new Date(newExpiry)
      gracePeriod.setDate(gracePeriod.getDate() + 3)

      // 4. Update Main Subscription
      await supabaseAdmin
        .from('subscriptions')
        .upsert({
          user_id: userId,
          plan_type: planType,
          status: 'active',
          expires_at: newExpiry.toISOString(),
          grace_period_ends_at: gracePeriod.toISOString(),
          updated_at: now.toISOString(),
          last_external_id: external_id,
        })

      // 5. Log to History
      await supabaseAdmin
        .from('subscription_history')
        .insert({
          user_id: userId,
          plan_type: planType,
          amount: amount,
          status: 'success',
          payment_method: payment_method,
          external_id: external_id,
          activated_at: now.toISOString(),
          expires_at: newExpiry.toISOString(),
        })

      console.log(`Upgraded user ${userId} to ${planType}. New expiry: ${newExpiry.toISOString()}`)
    }

    return new Response(JSON.stringify({ message: 'Success' }), { status: 200 })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 400 })
  }
})
