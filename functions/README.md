# Firebase Functions deployment notes

Set the OpenAI key as a Functions secret:

  firebase functions:secrets:set OPENAI_API_KEY

Then deploy:

  firebase deploy --only functions

Your HTTP endpoint will be:

  https://us-central1-e-commerce-nina-verde-vy-451f6.cloudfunctions.net/angelinaChat
