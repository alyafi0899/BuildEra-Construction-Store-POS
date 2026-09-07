import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const XENDIT_SECRET_KEY = Deno.env.get('XENDIT_SECRET_KEY')
    if (!XENDIT_SECRET_KEY) {
      throw new Error('XENDIT_SECRET_KEY is missing')
    }

    const { userId, planType, email, method } = await req.json()
    console.log(`Creating payment: user=${userId}, plan=${planType}, method=${method}`)

    const amount = planType === 'yearly' ? 1000000 : 100000
    const externalId = `${userId}_${planType}_${Date.now()}`

    // Construct the payload for Xendit
    const body: any = {
      external_id: externalId,
      amount: amount,
      payer_email: email || 'user@buildera.id',
      description: `BuildEra POS Subscription - ${planType.toUpperCase()}`,
      success_redirect_url: 'buidera://payment/success',
      failure_redirect_url: 'buidera://payment/failure',
      currency: 'IDR',
    }

    // If a specific method was chosen in Flutter, we can filter Xendit UI
    if (method === 'qris') {
      body.payment_methods = ['QRIS']
    } else if (method === 'va') {
      body.payment_methods = ['VIRTUAL_ACCOUNT']
    }

    const response = await fetch('https://api.xendit.co/v2/invoices', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${btoa(XENDIT_SECRET_KEY + ':')}`,
      },
      body: JSON.stringify(body),
    })

    const data = await response.json()

    if (!response.ok) {
      console.error('Xendit Error:', data)
      throw new Error(data.message || 'Xendit failed')
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
