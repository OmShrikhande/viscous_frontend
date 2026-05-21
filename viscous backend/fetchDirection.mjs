import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const serviceAccount = {"type":"service_account","project_id":"route-number-1","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDTlbd7h/Qa1RMs\nQzBuwWTErVpT5x0ghO9dXGvzVCTWFRaCxRfIiYS0xITFuyeGkQgpiH0TvP4EgGyW\nMheI96+kXI6LS8z/QMOo5ei9zhCv8saRhCx3YEd7Vbp5W74+dDezQa6fdcSrawV7\nl/yZESF9iznS/RSZpKt+uiBu7J8Dthzk2fxXa7G3GQkE7OSUJ+JUPZRQScLgHMJO\n/fCC6NgvapOUMdpLFGV43v26kInnuJc77Fb/i6zODk2wlfdUsEU72tIMGF1YB6X5\nHe+3p/XdUm5S9pVZ0/khePp+Ep9w8eVYdjRZkXfqNk2JKjFCO54uh+1CZzMkAZhv\nTT1PZxa7AgMBAAECggEACRaSNgUl8A0c8LbGGsvFx0jm61mu/5mWKn1wyZfgqS1o\ntR9AIUX+5EDYryGV1greveH19WYVxx25DE6EgkaZTccH/GW6HXCrttKBR73VK6mS\n6+cwfcQt7ddF1jahmk8loVZ96K2HUBGdv6xMlkqNFLZpOm3Sd7MCBsR55inVvrP8\n01q7+4uqmqvacaw8ukKC/K0MidcrRAnd147DBDUoOEMo8AsDfJ+G4GVv4fa0sNmj\nx51ewz/2e0QQAFEjp/eJDGIki8kz5xadc0aFj4u9pnY96KOTPDS9gVhLCGK+p0G6\neap/8Ja3aaWWGbNndtCU5l1XpmzCqG4Qe+ttWjlOgQKBgQDvXfWEeCZeeN9q/NXt\nONMXsgTfgrO3SwtdONxxjy0rmzw9zJrkq0f9O5Jf6UuJNPlcjtjz1wc7sC/tLVP9\nFvoMmXdBQ/VnUC5iSWzufEHoryEvt0TeHeTUwGb/ogoUyEQXo1feaRnXk8ISTETs\neKgmGf0DQZeztQ2t2YXd8gJ9ewKBgQDiSYwK5h+SJM+RtOhG4qFXfB0hq4J7sbPT\nuTmLDNEwOUvIKltA9OsZlQd5xKqGVN2L3RRDLnQYyrLh+o9e/pTA3zYZ7YlMZgRS\nVnsAInQJ41t/pGFtC7zJbhfbVQFx1O7Ck6eC2zfgU9EbBL0mB4DC1sV6nwLfRLC3\n7qL4of5nwQKBgD7YxZilTzWouMhHYAerzsi+5calc3ghjPdJ8Z8jP3HejT+Qk+6M\nBhe352OlRj7dGMezfcTv5SdHyB2WtCGUQczDEmuhYzJf+/20V5R6LXfhW25CySMk\naCtv5NsjeVAhkLdAHNb5c16FngPd4I7R0xxF4IdVVnZJiDDoFtzCKOM3AoGAHgk7\nIHs5N5HRR3rm1fnhBpa/2ydD051bzD+qxq012xvP1krg//dCeYvRiTU0mU4MdjMr\nLFuvJ1dIdTxn6WkLX6qBKOHhtpVX/4HhI7xvAJ0AGSo9kFbdgTMu0XswDOcBpiwp\nMPJeMVWOzPJNFQ4r5jDR15vhqrcYaeGwGiaOeUECgYEAjZHDgyMxxqWycMdThedl\nPRaiysJJ6jWfBvm0IxcYHByLsfESnRz2Ho1+ph4Ht3IlakiSrk3m7EXs1QMUA0HH\nLk8+ythrEpdQxNK2RFpu+ApcYBeWaCSXNrHTeC0jWDkmuR965edYZPm3SPLW8AwZ\nIDSQf/G0q3AtclkW6Fr65rY=\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-fbsvc@route-number-1.iam.gserviceaccount.com","client_id":"114440419688017159262","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40route-number-1.iam.gserviceaccount.com"};

const app = initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore(app);

async function fetchDirection() {
  // 1. Find the route by routeNumber R-26
  const routeSnap = await db.collection('routes').where('routeNumber', '==', 'R-26').limit(1).get();
  if (routeSnap.empty) {
    console.log('❌ Route R-26 not found in Firestore');
    process.exit(1);
  }
  const route = routeSnap.docs[0];
  const routeId = route.id;
  const routeData = route.data();

  console.log('\n=== ROUTE INFO ===');
  console.log('Route ID  :', routeId);
  console.log('Route No  :', routeData.routeNumber);
  console.log('Bus ID    :', routeData.busId);
  console.log('From      :', routeData.from);
  console.log('To        :', routeData.to);
  console.log('Stops in Sequence:');
  (routeData.stops ?? []).forEach((s, i) => {
    console.log(`  ${i}: ${s.name} (${s.coordinates ? s.coordinates.join(', ') : 'no coordinates'})`);
  });

  // 2. Fetch the live runtime data
  const runtimeSnap = await db.collection('route_runtime').doc(routeId).get();
  if (!runtimeSnap.exists) {
    console.log('\n❌ No runtime data found for this route yet.');
    process.exit(1);
  }
  const runtime = runtimeSnap.data();

  const direction = runtime.direction === -1 ? -1 : 1;
  const stopIndex = runtime.currentStopIndex ?? 'N/A';
  const nextStopIndex = runtime.nextStopIndex ?? 'N/A';
  const status = runtime.status ?? 'unknown';
  const updatedAt = runtime.updatedAt ?? 'N/A';

  // Get stop names
  const stops = (routeData.stops ?? []);
  const currentStopName = stops[stopIndex]?.name ?? 'Unknown';
  const nextStopName = stops[nextStopIndex]?.name ?? 'Unknown';

  console.log('\n=== LIVE BUS DIRECTION DATA ===');
  console.log('Direction         :', direction, direction === 1 ? '👉 FORWARD (Bhadura → S B Jain)' : '👈 RETURN  (S B Jain → Bhadura)');
  console.log('Status            :', status.toUpperCase());
  console.log('Current Stop Index:', stopIndex, `→ "${currentStopName}"`);
  console.log('Next Stop Index   :', nextStopIndex, `→ "${nextStopName}"`);
  console.log('Rounds Completed  :', runtime.roundsCompleted ?? 0);
  console.log('Speed (km/h)      :', runtime.speedKmh ?? 0);
  console.log('Last Updated      :', updatedAt);
  console.log('');
  process.exit(0);
}

fetchDirection().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
